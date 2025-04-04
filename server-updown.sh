#!/bin/bash
# This script starts up and shuts down the server
# such that it is inaccessible during school hours.

# Variable initialization
SCHOOL_START=800
SCHOOL_END_MTh=1500
SCHOOL_END_F=1300
SERVER_STATE="-1"
OVERRIDE="none"

while true; do
    DAY=$(date +%A)
    # calculate current time, remove leading zeroes, convert to numeric
    CURRENT_TIME=$(date +%H%M)
    CURRENT_TIME=${CURRENT_TIME#0}
    
    # Determine proper server state given time
    if [[ "$OVERRIDE" == "off" ]]; then
        SERVER_UP="0"
    elif [[ "$CURRENT_TIME" -lt "$SCHOOL_START" ]]; then
        SERVER_UP="1"
    elif [[ "$CURRENT_TIME" -gt "$SCHOOL_END_MTh" ]]; then
        SERVER_UP="1"
    elif [[ "$DAY" == "Friday" && "$CURRENT_TIME" -gt "$SCHOOL_END_F" ]]; then
        SERVER_UP="1"
    elif [[ "$OVERRIDE" == "on" ]]; then
        SERVER_UP="1"
    else
        SERVER_UP="0"
    fi
    
    # Start/stop the server accordingly
    if [[ "$SERVER_UP" == "1" && "$SERVER_STATE" != "1" ]]; then
        docker start chaos && SERVER_STATE="1"
        echo "Started server at $(date)."
    elif [[ "$SERVER_UP" == "0" && "$SERVER_STATE" != "0" ]]; then
        docker stop chaos && SERVER_STATE="0"
        echo "Stopped server at $(date)."
    fi
    
    # check again in 1 minute
    sleep 59
done


