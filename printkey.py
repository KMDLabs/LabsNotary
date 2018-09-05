#!/usr/bin/env python3
import configparser
import sys

# read configuration file
ENVIRON = 'PROD'
config = configparser.ConfigParser()
config.read('config.ini')

# read key to print form env var
try:
    keytoprint = sys.argv[1]
except:
    sys.exit(0)

# print the key asked for
if keytoprint == 'pub':
    print(config[ENVIRON]['btcpubkey'])
if keytoprint == 'wif':
    print(config[ENVIRON]['wifkey'])
if keytoprint == 'Radd':
    print(config[ENVIRON]['Radd'])
