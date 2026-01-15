#!/bin/bash
#define some variables
readonly EMAIL=$1
readonly AT="@"
readonly DOMAIN=${EMAIL#*$AT}
readonly INDEX=${#EMAIL}-${#DOMAIN}-1
readonly USER=${EMAIL:0:INDEX}
if [ "$DOMAIN" = "gmail.com" ]; then
    SECOND_MAIL=${USER}+'@googlemail.com'
elif [ "$DOMAIN" = "googlemail.com" ]; then
    SECOND_MAIL=${USER}+'@gmail.com'
else
    SECOND_MAIL=''
fi

echo "Füge E-Mail-Adresse $1 den Verteilern hinzu"
ezmlm-sub ~/ezmlm/verein "$EMAIL"
ezmlm-sub ~/ezmlm/trainer allow "$EMAIL"
ezmlm-sub ~/ezmlm/vorstand allow "$EMAIL"
if [ -z ${SECOND_MAIL+x} ]; then
    ezmlm-sub ~/ezmlm/trainer allow "$SECOND_MAIL"
    ezmlm-sub ~/ezmlm/vorstand allow "$SECOND_MAIL"
fi
echo "... fertig"


