#!/usr/bin/env python2
import os
import json
import sys

if len(sys.argv) > 1:
    specific_chain = sys.argv[1]
else:
    specific_chain = False

def format_param(param, value):
    return '-' + str(param) + '=' + str(value)

def format_bool(param):
    return '-' + str(param)

script_dir = os.getcwd()
with open(script_dir + '/assetchains.json') as file:
    assetchains = json.load(file)

    for chain in assetchains:
        if specific_chain and chain['ac_name'] != specific_chain:
            continue
        params = []
        for param, value in chain.items():
            if param == 'freq':
                continue
            if param == 'branch':
                continue
            if param == 'iguana':
                continue
            if param == 'iguana_rpc':
                continue
            if param == 'iguana_port':
                continue
            if type(value) is bool:
                params.append(format_bool(param))
                continue
            if isinstance(value, list):
                for dupe_value in value:
                    params.append(format_param(param, dupe_value))
            else:
                params.append(format_param(param, value))
        print(' '.join(params))
