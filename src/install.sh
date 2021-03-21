#!/usr/bin/env bash

mkdir -p "$HOME/bin/serverlogger/bash-clients/includes"

pushd "$HOME/bin/serverlogger/bash-clients/includes" || exit 1
  curl --silent -O https://raw.githubusercontent.com/serverlogger/bash-clients/main/src/includes/colors.sh
  pushd .. || exit 1
    curl --silent -O https://raw.githubusercontent.com/serverlogger/bash-clients/main/src/setup.sh
    curl --silent -O https://raw.githubusercontent.com/serverlogger/bash-clients/main/src/streamfile.sh
  popd
popd || exit 1

/usr/bin/env bash "$HOME/bin/serverlogger/bash-clients/setup.sh"
