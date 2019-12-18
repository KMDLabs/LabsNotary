#!/usr/bin/env python2
import os
import json
import sys

if len(sys.argv) > 1:
    specific_coin= sys.argv[1]
else:
    specific_coin = False

script_dir = os.getcwd()
with open(script_dir + '/assetchains.json') as file:
    assetchains = json.load(file)

# always check master
print("master")

for chain in assetchains:
    if specific_coin and chain['ac_name'] != specific_coin:
        continue
    try:
        print(chain['branch'])
    except:
        print("master")
