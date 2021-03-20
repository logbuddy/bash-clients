#!/usr/bin/env bash

confDir="$HOME/.serverlogger"
confEmailFile="$HOME/.serverlogger/email"
confWebappApiKeyIdFile="$HOME/.serverlogger/webappApiKeyId"

response=""
statusCode=""
body=""

cleanup () {
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
echo "Welcome to the ServerLogger CLI setup."
echo ""

echo -n "Your ServerLogger.com e-mail address: "
read -r -e email

echo -n "Your ServerLogger.com password: "
read -r -e password

echo ""

callApi users POST '{"email": "'"$email"'", "password": "'"$password"'"}'

if [ "$statusCode" == "201" ]
then
  echo -n "Successfully registered new account '$email', logging in... "
elif [ "$statusCode" == "400" ]
then
  echo -n "Account with e-mail address '$email' already exists, logging in... "
else
  echo "Registration failed with status code $statusCode:"
  echo "$body"
  cleanup
  exit 1
fi


callApi webapp-api-keys POST '{"email": "'"$email"'", "password": "'"$password"'"}'

if [ "$statusCode" != "201" ]
then
  echo "Login failed with status code $statusCode:"
  echo "$body"
  cleanup
  exit 1
else
  echo "done."
  echo ""
  echo "Storing your credentials:"

  webappApiKeyId="${body//\"/}"

  echo -n "  $confEmailFile... "
  echo "$email" > "$confEmailFile"
  echo "done"

  echo -n "  $confWebappApiKeyIdFile... "
  echo "$webappApiKeyId" > "$confWebappApiKeyIdFile"
  echo "done."

  echo ""

  echo -n "Verifying API connection... "
  callApiWithWebappApiKey servers GET "$webappApiKeyId" ''

  if [ "$statusCode" == "200" ]
  then
    echo "done."
    echo ""

    if [ "$body" == "[]" ]
    then
      echo ""
      echo "Let's now create your first server on ServerLogger.com."

      serverTitle=""
      while [ "$serverTitle" == "" ]
      do
        echo -n "Name of your server (default: '$(hostname | xargs)'): "
        read -r -e serverTitle
        serverTitle="$(echo $serverTitle | xargs)"

        if [ "$serverTitle" == "" ]
        then
          serverTitle="$(hostname | xargs)"
        fi

        if [ "$serverTitle" == "" ]
        then
          echo "Invalid server name, please try again"
          echo ""
        fi
      done

      echo ""
      echo -n "Ok, going to create server '$serverTitle'... "
      callApiWithWebappApiKey servers POST "$webappApiKeyId" '{ "title": "'"$serverTitle"'" }'

      if [ "$statusCode" == "201" ]
      then
        echo "done."
        echo ""

        cleanedUpBody="$(echo "$body" | sed 's/{//g' | sed 's/}//g' | sed 's/"//g')"
        serverId="$(echo "$cleanedUpBody" | cut -d ',' -f 1 | cut -d ':' -f 2)"
        userId="$(echo "$cleanedUpBody" | cut -d ',' -f 2 | cut -d ':' -f 2)"
        loggingApiKeyId="$(echo "$cleanedUpBody" | cut -d ',' -f 3 | cut -d ':' -f 2)"

        echo "$serverId"
        echo "$userId"
        echo "$loggingApiKeyId"
      else
        echo "Server creation failed with status code $statusCode:"
        echo "$body"
        cleanup
        exit 1
      fi
    fi

  else
    echo "error."
    echo "API connection failed with status code $statusCode:"
    echo "$body"
    cleanup
    exit 1
  fi
fi

cleanup
