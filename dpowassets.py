#!/usr/bin/env python3
import requests
import json
import pprint
import sys
import os
import configparser
import csv

# read configuration file
ENVIRON = 'PROD'
config = configparser.ConfigParser()
config.read('config.ini')

# Read the assetchians.json file
script_dir = os.getcwd()
with open(script_dir + '/assetchains.json') as file:
    assetchains = json.load(file)

# configure pretty printer
pp = pprint.PrettyPrinter(width=41, compact=True)

# get connection options
conn = {}
connection_options = [
    'iguana_ip',
    'iguana_port']
for i in connection_options:
    conn[i] = config[ENVIRON][i]
    
if len(sys.argv) > 1:
    specific_iguana = sys.argv[1]
else:
    specific_iguana = False

# define function that posts json data to iguana
def post_rpc(url, payload, auth=None):
    try:
        r = requests.post(url, data=json.dumps(payload), auth=auth)
        return(json.loads(r.text))
    except Exception as e:
        raise Exception("Couldn't connect to " + url + ": ", e)

# define url's
iguana_url = 'http://' + conn['iguana_ip'] + ':' + conn['iguana_port']

# set btcpubkey
btcpubkey = config[ENVIRON]['btcpubkey']

# dpow
def dpow(symbol, freq, iguana_rpc, iguana):
    payload = {
        "agent": "iguana",
        "method": "dpow",
        "symbol": symbol,
        "freq": freq,
        "pubkey": btcpubkey
    }
    # define url's
    iguana_url = 'http://' + conn['iguana_ip'] + ':' + iguana_rpc
    try:
        response_dpow = post_rpc(iguana_url, payload)
        print('== response_dpow ' + symbol + ' ==')
        pp.pprint(response_dpow)
    except Exception as e:
        print('== response_dpow ' + iguana + ' FAILED TO START! ==')

# dpow assetchains
for chain in assetchains:
    ac_chain = chain['ac_name']
    iguana_rpc = chain['iguana_rpc']
    iguana = chain['iguana']
    if specific_iguana and iguana != specific_iguana:
        continue
    for param, value in chain.items():
        if param == 'freq':
            ac_freq = chain['freq']
            dpow(ac_chain,ac_freq,iguana_rpc,iguana)
