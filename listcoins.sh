#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

echo "KMD"
./listassetchains.py
