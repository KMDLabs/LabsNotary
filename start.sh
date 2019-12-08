#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
git pull
./starting.sh "${@}"
