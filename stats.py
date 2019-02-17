#!/usr/bin/env python3

import re
import json
import platform
import os
import bitcoin
from bitcoin.wallet import P2PKHBitcoinAddress
from bitcoin.core import x
from bitcoin.core import CoreMainParams

class CoinParams(CoreMainParams):
    MESSAGE_START = b'\x24\xe9\x27\x64'
    DEFAULT_PORT = 7770
    BASE58_PREFIXES = {'PUBKEY_ADDR': 60,
                       'SCRIPT_ADDR': 85,
                       'SECRET_KEY': 188}

bitcoin.params = CoinParams

from slickrpc import Proxy

def colorize(string, color):
    colors = {
        'blue': '\033[94m',
        'magenta': '\033[95m',
        'green': '\033[92m',
        'red': '\033[91m'
    }
    if color not in colors:
        return string
    else:
        return colors[color] + string + '\033[0m'


# fucntion to define rpc_connection
def def_credentials(chain):
    rpcport = '';
    operating_system = platform.system()
    if operating_system == 'Darwin':
        ac_dir = os.environ['HOME'] + '/Library/Application Support/Komodo'
    elif operating_system == 'Linux':
        ac_dir = os.environ['HOME'] + '/.komodo'
    elif operating_system == 'Windows':
        ac_dir = '%s/komodo/' % os.environ['APPDATA']
    if chain == 'KMD':
        coin_config_file = str(ac_dir + '/komodo.conf')
    else:
        coin_config_file = str(ac_dir + '/' + chain + '/' + chain + '.conf')
    with open(coin_config_file, 'r') as f:
        for line in f:
            l = line.rstrip()
            if re.search('rpcuser', l):
                rpcuser = l.replace('rpcuser=', '')
            elif re.search('rpcpassword', l):
                rpcpassword = l.replace('rpcpassword=', '')
            elif re.search('rpcport', l):
                rpcport = l.replace('rpcport=', '')
    if len(rpcport) == 0:
        if chain == 'KMD':
            rpcport = 7771
        else:
            print("rpcport not in conf file, exiting")
            print("check " + coin_config_file)
            exit(1)

    return (Proxy("http://%s:%s@127.0.0.1:%d" % (rpcuser, rpcpassword, int(rpcport))))

CHAIN = input('Please specify chain: ')
ADDRESS = 'RXL3YXG2ceaB6C5hfJcN4fvmLH2C34knhA'
rpc_connection = def_credentials(CHAIN)

getinfo_result = rpc_connection.getinfo()
height = getinfo_result['blocks']
getnotarysendmany_result = rpc_connection.getnotarysendmany()
iguana_json = rpc_connection.getiguanajson()
notary_keys = {}
score = {}

for notary in iguana_json['notaries']:
    for i in notary:
        addr = str(P2PKHBitcoinAddress.from_pubkey(x(notary[i])))
        notary_keys[addr] = i

for block in range(2,height):
    getblock_result = rpc_connection.getblock(str(block), 2)
    if len(getblock_result['tx'][0]['vout']) > 1:
        vouts = getblock_result['tx'][0]['vout']
        for vout in vouts[1:]:
            addr = vout['scriptPubKey']['addresses'][0]
            if addr in getnotarysendmany_result:
                getnotarysendmany_result[addr] += 1
            else:
                print('BUG in the coinbase tx, please report this.')

for i in notary_keys:
    score[notary_keys[i]] = getnotarysendmany_result[i]

getinfo_result = rpc_connection.getinfo()
if 'notaryname' in getinfo_result:
    notaryname = getinfo_result['notaryname']

s = [(k, score[k]) for k in sorted(score, key=score.get, reverse=True)]
for k, v in s:
    if k == notaryname:
        myscore = str(k) + ' ' + str(v)
        print(colorize(myscore, 'green'))
    else:
        print(k, v)
