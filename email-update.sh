#!/usr/bin/env bash

readonly SQL_QUERY="SELECT id,u.change,email_address,inserted_at FROM email_update u;"
readonly CLUB_LIST="$HOME/ezmlm/verein"
readonly COACH_LIST="$HOME/ezmlm/trainer"
readonly BOARD_LIST="$HOME/ezmlm/vorstand"
ROWS=()
IDS=()

function addNewEmail {
#define some variables
local -r EMAIL=$1
local -r AT="@"
local -r DOMAIN=${EMAIL#*"$AT"}
local -r INDEX=${#EMAIL}-${#DOMAIN}-1
local -r USER=${EMAIL:0:INDEX}
if [ "$DOMAIN" = "gmail.com" ]; then
    SECOND_MAIL=${USER}+'@googlemail.com'
elif [ "$DOMAIN" = "googlemail.com" ]; then
    SECOND_MAIL=${USER}+'@gmail.com'
else
    SECOND_MAIL=''
fi

echo "Füge E-Mail-Adresse ${EMAIL} den Verteilern hinzu"
ezmlm-sub "${CLUB_LIST}" "$EMAIL"
ezmlm-sub "${COACH_LIST}" allow "$EMAIL"
ezmlm-sub "${BOARD_LIST}" allow "$EMAIL"
if [ -z ${SECOND_MAIL+x} ]; then
    ezmlm-sub "${COACH_LIST}" allow "$SECOND_MAIL"
    ezmlm-sub "${BOARD_LIST}" allow "$SECOND_MAIL"
fi
echo "... fertig"

}

function removeOldEmail {
    ezmlm-unsub "${CLUB_LIST}" "$1"
}

function handleSingleUpdate {
  # split contents of $1 into an array name columns
  read -r -a columns <<< "$1"

  local -r ID="${columns[0]}"
  local -r CHANGE="${columns[1]}"
  local -r EMAIL="${columns[2]}"

  if [ "${CHANGE}" -eq 0 ]; then
    printf "Add mail address %s\n" "${EMAIL}"
    addNewEmail "${EMAIL}"
  else
    printf "Remove mail address %s\n" "${EMAIL}"
    removeOldEmail "${EMAIL}"
  fi

  # store id of processed update in IDS array
  IDS+=( "${ID}" )
}


# read update from database and store them in ROWS array
mapfile -t  ROWS < <(mariadb -D guc_members -e "${SQL_QUERY}"  -N -B)

for update in "${ROWS[@]}"
do
    handleSingleUpdate "${update}"
done

#only remove rows from email_update table if any changes have been made
if (( ${#IDS[@]} )); then
  TMP_IDS=$(printf ",%s" "${IDS[@]}")
  readonly TMP_IDS

  IDS_TO_DELETE=${TMP_IDS:1}
  readonly IDS_TO_DELETE

  REMOVE_QUERY=$(printf "DELETE FROM email_update WHERE id in (%s)" "${IDS_TO_DELETE}")
  readonly REMOVE_QUERY

  printf "executing query: %s" "${REMOVE_QUERY}"
  mariadb -D guc_members -e "${REMOVE_QUERY}" -N -B
fi
