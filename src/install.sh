#!/usr/bin/env bash

mkdir -p "$HOME/serverlogger/bash-clients/includes"

pushd "$HOME/serverlogger/bash-clients/includes" || exit 1
  curl -O https://raw.githubusercontent.com/serverlogger/bash-clients/main/src/includes/colors.sh
  pushd .. || exit 1
    curl -O https://raw.githubusercontent.com/serverlogger/bash-clients/main/src/setup.sh
    curl -O https://raw.githubusercontent.com/serverlogger/bash-clients/main/src/streamfile.sh
  popd
popd || exit 1

/usr/bin/env bash "$HOME/serverlogger/bash-clients/setup.sh"
