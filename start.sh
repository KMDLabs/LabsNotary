#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
git pull
sleep 1
./starting.sh
