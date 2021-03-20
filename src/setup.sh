#!/usr/bin/env bash

scriptFolder="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source "$scriptFolder/includes/colors.sh"

confDir="$HOME/.serverlogger"
confEmailFile="$HOME/.serverlogger/email"
confWebappApiKeyIdFile="$HOME/.serverlogger/webappApiKeyId"
confLoggingApiKeyIdFile="$HOME/.serverlogger/loggingApiKeyId"
confUserIdFile="$HOME/.serverlogger/userId"
confServerIdFile="$HOME/.serverlogger/serverId"

response=""
statusCode=""
body=""

resetColor() {
  echo -n -e "${RCol}"
}

cleanup () {
  resetColor
  rm -rf "$curlContentDir"
}

callApi () {
  response=$(curl \
  --silent \
  --verbose \
	"https://rs213s9yml.execute-api.eu-central-1.amazonaws.com/$1" \
	-X "$2" \
	-H "Content-Type: application/json" \
	-H "Pragma: no-cache" \
	-H "Cache-Control: no-cache" \
	--data-raw "$3" \
	--output "$curlContentDir/latest" \
	2>&1)
	statusCode="$(getStatusCode "$response")"
  body="$(getBody "$response")"
}

callApiWithWebappApiKey () {
  response=$(curl \
  --silent \
  --verbose \
	"https://rs213s9yml.execute-api.eu-central-1.amazonaws.com/$1" \
	-X "$2" \
	-H "Content-Type: application/json" \
	-H "Pragma: no-cache" \
	-H "Cache-Control: no-cache" \
	-H "X-Herodot-Webapp-Api-Key-Id: $3" \
	--data-raw "$4" \
	--output "$curlContentDir/latest" \
	2>&1)
	statusCode="$(getStatusCode "$response")"
  body="$(getBody "$response")"
}

getStatusCode () {
  echo "$1" | grep "< HTTP/2 " | cut -d " " -f 3
}

getBody () {
  cat "$curlContentDir/latest"
}


if [[ ! -x "$(which curl)" ]]
then
  echo "Looks like 'curl' is not available on your system, please install and retry."
  exit 1
fi

if ! mkdir -p "$confDir"
then
  echo "Could not create configuration directory $confDir, aborting."
  exit 1
fi

curlContentDir="$(mktemp -d)"

echo ""
echo -e "${On_Gre}                                        ${RCol}"
echo -e "${On_Gre}${BWhi} Welcome to the ServerLogger CLI setup. ${RCol}"
echo -e "${On_Gre}                                        ${RCol}"
echo ""

echo -e "You first need to ${BWhi}register with us${RCol} or ${BWhi}log in${RCol}."
echo ""
echo "Simply enter your credentials - we will either create a new"
echo "account for you or log you into your existing account."
echo ""

echo -n -e "Your ServerLogger.com ${BWhi}e-mail address${RCol}:${BPur}"
read -r -e -p ' ' email
resetColor

echo -n -e "Your ServerLogger.com ${BWhi}password${RCol}: ${BPur}"
unset password;
while IFS= read -r -s -n1 pass; do
  if [[ -z $pass ]]; then
     echo
     break
  else
     echo -n '*'
     password+=$pass
  fi
done
resetColor

echo ""

callApi users POST '{"email": "'"$email"'", "password": "'"$password"'"}'

if [ "$statusCode" == "201" ]
then
  echo -n -e "Successfully registered new account ${BPur}$email${RCol}, logging in... "
elif [ "$statusCode" == "400" ]
then
  echo -n -e "Account with e-mail address ${BPur}$email${RCol} already exists, logging in... "
else
  echo -e "Registration failed with status code ${BRed}$statusCode${RCol}:"
  echo -e "${BYel}$body${RCol}"
  cleanup
  exit 1
fi


callApi webapp-api-keys POST '{"email": "'"$email"'", "password": "'"$password"'"}'

if [ "$statusCode" != "201" ]
then
  echo -e "${BRed}failure${RCol}"
  echo -e "Login failed with status code ${BRed}$statusCode${RCol}:"
  echo -e "${BYel}$body${RCol}"
  cleanup
  exit 1
else
  echo -e "${BGre}success${RCol}"
  echo ""
  echo "Storing your credentials:"

  webappApiKeyId="${body//\"/}"

  echo -n "  $confEmailFile... "
  echo "$email" > "$confEmailFile"
  echo -e "${BGre}success${RCol}"

  echo -n "  $confWebappApiKeyIdFile... "
  echo "$webappApiKeyId" > "$confWebappApiKeyIdFile"
  echo -e "${BGre}success${RCol}"

  echo ""

  echo -n "Verifying API connection... "
  callApiWithWebappApiKey servers GET "$webappApiKeyId" ''

  if [ ! "$statusCode" == "200" ]
  then
    echo -e "${BRed}failure${RCol}"
    echo -e "API connection failed with status code ${BRed}$statusCode${RCol}:"
    echo -e "${BYel}$body${RCol}"
    cleanup
    exit 1
  else
    echo -e "${BGre}success${RCol}"
    echo ""

    if [ "$body" == "[]" ]
    then
      echo -e "Let's now register this machine as ${BWhi}your first server${RCol} on ServerLogger.com."
    else
      echo -e "Let's now register this machine as ${BWhi}as an additional server${RCol} on ServerLogger.com."
    fi

    serverTitle=""
    while [ "$serverTitle" == "" ]
    do
      echo -n -e "${BWhi}Name of your server${RCol} (default: '${BPur}$(hostname | xargs)${RCol}'):${BPur}"
      read -r -e -p ' ' serverTitle
      resetColor
      serverTitle="$(echo $serverTitle | xargs)"

      if [ "$serverTitle" == "" ]
      then
        serverTitle="$(hostname | xargs)"
      fi

      if [ "$serverTitle" == "" ]
      then
        echo -e "${BYel}Invalid server name, please try again.${RCol}"
        echo ""
      fi
    done

    echo ""
    echo -n -e "Ok, going to create server ${BPur}$serverTitle${RCol} on ServerLogger.com... "
    callApiWithWebappApiKey servers POST "$webappApiKeyId" '{ "title": "'"$serverTitle"'" }'

    if [ "$statusCode" == "201" ]
    then
      echo -e "${BGre}success${RCol}"
      echo ""

      cleanedUpBody="$(echo "$body" | sed 's/{//g' | sed 's/}//g' | sed 's/"//g')"
      serverId="$(echo "$cleanedUpBody" | cut -d ',' -f 1 | cut -d ':' -f 2)"
      userId="$(echo "$cleanedUpBody" | cut -d ',' -f 2 | cut -d ':' -f 2)"
      loggingApiKeyId="$(echo "$cleanedUpBody" | cut -d ',' -f 3 | cut -d ':' -f 2)"

      echo "Storing your server credentials:"

      echo -n "  $confUserIdFile... "
      echo "$userId" > "$confUserIdFile"
      echo -e "${BGre}success${RCol}"

      echo -n "  $confServerIdFile... "
      echo "$serverId" > "$confServerIdFile"
      echo -e "${BGre}success${RCol}"

      echo -n "  $confLoggingApiKeyIdFile... "
      echo "$loggingApiKeyId" > "$confLoggingApiKeyIdFile"
      echo -e "${BGre}success${RCol}"

      echo ""
    else
      echo -e "${BRed}failure${RCol}"
      echo -e "Server creation failed with status code ${BRed}$statusCode${RCol}:"
      echo -e "${BYel}$body${RCol}"
      cleanup
      exit 1
    fi
  fi
fi

cleanup
