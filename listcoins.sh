#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

./listassetchains.py
echo "KMD"
