#!/bin/bash
echo "Stopping Iguana"
pkill -15 iguana
./assets-cli stop
komodo-cli stop
