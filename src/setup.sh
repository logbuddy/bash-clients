#!/usr/bin/env bash

echo -n "Your E-Mail address: "
read -r -e email

echo -n "Your password: "
read -r -e password

callApi () {
  curl \
  --silent \
  --verbose \
	"https://rs213s9yml.execute-api.eu-central-1.amazonaws.com/$1" \
	-X "$2" \
	-H 'Content-Type: application/json' \
	-H 'Pragma: no-cache' \
	-H 'Cache-Control: no-cache' \
	--data-raw "$3" \
	2>&1 \
	| grep -v "^* " \
	| sed -e 's/* Closing connection 0//g'
}

getStatusCode () {
  echo "$1" | grep "< HTTP/2 " | cut -d " " -f 3
}

getBody () {
  echo "$1" | grep -v "^< " | grep -v "^> "
}

response="$(callApi users POST '{"email": "'"$email"'", "password": "'"$password"'"}' )"

#echo "$response"

if [ "$(getStatusCode "$response")" == "201" ]
then
  echo "Registration successful."
else
  echo "Registration failed: $(getBody "$response")"
fi
