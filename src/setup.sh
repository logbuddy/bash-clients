#!/usr/bin/env bash

confDir="$HOME/.serverlogger"
confEmailFile="$HOME/.serverlogger/email"
confWebappApiKeyIdFile="$HOME/.serverlogger/webappApiKeyId"

callApi () {
  curl \
  --silent \
  --verbose \
	"https://rs213s9yml.execute-api.eu-central-1.amazonaws.com/$1" \
	-X "$2" \
	-H "Content-Type: application/json" \
	-H "Pragma: no-cache" \
	-H "Cache-Control: no-cache" \
	--data-raw "$3" \
	--output "$curlContentDir/latest" \
	2>&1
}

callApiWithWebappApiKey () {
  curl \
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
	2>&1
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

response="$(callApi users POST '{"email": "'"$email"'", "password": "'"$password"'"}' )"
statusCode="$(getStatusCode "$response")"
body="$(getBody "$response")"

if [ "$statusCode" == "201" ]
then
  echo -n "Successfully registered new account '$email', logging in... "
elif [ "$statusCode" == "400" ]
then
  echo -n "Account with e-mail address '$email' already exists, logging in... "
else
  echo "Registration failed with status code $statusCode: $body"
  exit 1
fi


response="$(callApi webapp-api-keys POST '{"email": "'"$email"'", "password": "'"$password"'"}' )"
statusCode="$(getStatusCode "$response")"
body="$(getBody "$response")"

if [ "$statusCode" == "201" ]
then
  echo "done."
  echo ""
  echo -n "Storing your credentials in $confEmailFile and $confWebappApiKeyIdFile... "

  webappApiKeyId="${body//\"/}"
  echo "$email" > "$confEmailFile"
  echo "$webappApiKeyId" > "$confWebappApiKeyIdFile"

  echo "done."
  echo ""

  response="$(callApiWithWebappApiKey servers GET "$webappApiKeyId" '' )"
  statusCode="$(getStatusCode "$response")"
  body="$(getBody "$response")"
  echo "$body"
else
  echo "Login failed with status code $statusCode: $body"
fi

rm -rf "$curlContentDir"
