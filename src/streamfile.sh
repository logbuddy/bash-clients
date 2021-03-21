#!/usr/bin/env bash

trap "kill 0" SIGINT

scriptFolder="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source "$scriptFolder/includes/colors.sh"


defaultSource="$(hostname)"
defaultUserId="$(cat "$HOME/.serverlogger/userId")"
defaultServerId="$(cat "$HOME/.serverlogger/serverId")"
defaultUserId="$(cat "$HOME/.serverlogger/userId")"
defaultLoggingApiKeyId="$(cat "$HOME/.serverlogger/loggingApiKeyId")"

filePath="$1"
source="${2:-$defaultSource}"
userId="${3:-$defaultUserId}"
serverId="${4:-$defaultServerId}"
loggingApiKeyId="${5:-$defaultLoggingApiKeyId}"
bufferSize="${6:-100}"
controlTimeout="${5:-10}"
grepFilter="$8"

controlFilePath="$(mktemp)"
controlFileLine="--- ServerLogger.com streamfile.sh control file entry ---"

source="${source:0:256}"

i=0
eventsBuffer=()
eventsString=""

grepCommand="grep ''"
if [ "$grepFilter" != "" ]
then
  grepCommand="grep -v '$grepFilter'"
  echo "Filtering lines through: $grepCommand"
fi

while true; do
  sleep "$controlTimeout"
  echo "$controlFileLine" >> "$controlFilePath"
done &


echo -e "Streaming new contents in ${BPur}$filePath${RCol} to ServerLogger.com..."

tail -n0 -F -q "$filePath" "$controlFilePath" | while read -r line; do

  line="${line:0:512}"

  if [ "$line" != "$controlFileLine" ]
  then
    line=$(echo "$line" |eval "$grepCommand")
  fi

  if [ "$line" = "" ]
  then
    continue
  fi

  if [ "$line" != "$controlFileLine" ]
  then
    eventsBuffer[${#eventsBuffer[@]}]='{"source":"'"$source"'", "createdAt":"'"$(date +"%Y-%m-%dT%H:%M:%S%z")"'", "payload":"'"$(echo $line | sed "s/\"/\\\\\"/g")"'"}'
  fi

  if [ "$i" = "$bufferSize" ] || [ "$line" = "$controlFileLine" ]
  then
    j=0
    for eventString in "${eventsBuffer[@]}"
    do
	    if [ "$j" == 0 ]
	    then
        eventsString="$eventString"
      else
        eventsString="$eventsString,
$eventString"
      fi
      j=$((j+1))
    done

    if [ "$j" != 0 ]
    then
      date
      echo "$eventsString"
      curl \
        -X POST \
        "https://rs213s9yml.execute-api.eu-central-1.amazonaws.com/server-events" \
        -d '{ "userId":   "'"$userId"'",
              "serverId": "'"$serverId"'",
              "apiKeyId": "'"$loggingApiKeyId"'",
              "events":   ['"$eventsString"']}'

        i=0
        eventsBuffer=()
        echo ""
        echo ""
    fi

  else
    i=$((i+1))
  fi
done
