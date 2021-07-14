#!/bin/bash

# This script checks the logs for "Accepting" which indicates a bid.
# Setting to change in OT-Settings/config.sh:
# BID_CHECK_JOB_NOTIFY_ENABLED: Set to false to disable bid notifications (default true)
# BID_CHECK_INTERVAL: Set this to how far back to search the log for mentions of "Accepting" (default 1 hour).
# This value should match the CRON schedule. For example, Every 1 hour
# CRON should run this script which checks the logs for the past 1 hour.

source /root/OT-Settings/config.sh

BIDS=$(journalctl -u otnode.service --since "$BID_CHECK_INTERVAL" | grep Accepting | wc -l)
#echo Bids: $BIDS

if [ $BIDS -eq 0 ]; then
  /root/OT-NodeWatch/data/send.sh "Has not bid since BID_CHECK_INTERVAL, restarting node"
  systemctl restart otnode
fi

JOBS=$(journalctl -u otnode.service --since "BID_CHECK_INTERVAL" | grep 've been chosen' | wc -l)
#echo Jobs: $JOBS

OFFER_ID=($(journalctl -u otnode.service --since "BID_CHECK_INTERVAL" | grep 've been chosen' | grep -Eo '0x[a-z0-9]+'))

#echo Array: ${#OFFER_ID[@]}
if [ $BID_CHECK_JOB_NOTIFY_ENABLED == "true" ]
then
  for i in "${OFFER_ID[@]}"
  do
    TOKEN_ARRAY=($(curl -sX GET "https://v5api.othub.info/api/Job/detail/$i" -H  "accept: text/plain" | jq '.TokenAmountPerHolder' | cut -d'"' -f2))
    JOBTIME_ARRAY=($(curl -sX GET "https://v5api.othub.info/api/Job/detail/$i" -H  "accept: text/plain" | jq '.HoldingTimeInMinutes'))
    DAYS=$(expr ${JOBTIME_ARRAY[@]} / 60 / 24)
    /root/OT-Settings/data/send.sh "Job awarded: $DAYS days at ${TOKEN_ARRAY[@]} TRAC"
  done
fi
