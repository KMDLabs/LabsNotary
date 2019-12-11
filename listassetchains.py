#!/usr/bin/env python2
import os
import json
import sys

if len(sys.argv) > 1:
    specific_iguana = sys.argv[1]
else:
    specific_iguana = False

script_dir = os.getcwd()
with open(script_dir + '/assetchains.json') as file:
    assetchains = json.load(file)

for chain in assetchains:
    iguana = "blackjok3r"
    if iguana in chain:
        iguana = chain['iguana']
    if specific_iguana and iguana != specific_iguana:
        continue
    print(chain['ac_name'])
