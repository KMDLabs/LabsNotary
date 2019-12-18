#!/usr/bin/env python3
import lib
import sys
import bitcoin
from bitcoin.wallet import P2PKHBitcoinAddress
from bitcoin.core import x
from bitcoin.core import CoreMainParams
import argparse

parser = argparse.ArgumentParser(description='Display notarization stats for a running LABS Smart Chain.')
parser.add_argument('--name', type=str, help='Name of the Smart Chain.')
parser.add_argument('--number', type=int, help='Number of previous blocks.(0 for all)')

args = parser.parse_args()

class CoinParams(CoreMainParams):
    MESSAGE_START = b'\x24\xe9\x27\x64'
    DEFAULT_PORT = 7770
    BASE58_PREFIXES = {'PUBKEY_ADDR': 60,
                       'SCRIPT_ADDR': 85,
                       'SECRET_KEY': 188}

bitcoin.params = CoinParams

if not args.name:
    CHAIN = input('Please specify chain: ')
else:
    CHAIN = args.name

ADDRESS = 'RXL3YXG2ceaB6C5hfJcN4fvmLH2C34knhA'

try:
    rpc_connection = lib.def_credentials(CHAIN)
except:
    print(CHAIN + ' daemon is not running or RPC creds not found')
    sys.exit(0)


if not args.number:
    try:
        block_range = int(
            input('Please specify amount of previous blocks(0 for all): '))
    except:
        print('Blocks must be whole number. Exiting...')
        sys.exit(0)
else:
    block_range = args.number

print('Please wait...')


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

start_height = height - block_range
if block_range == 0 or block_range > height:
    start_height = 2


for block in range(start_height,height):
    getblock_result = rpc_connection.getblock(str(block), 2)
    if len(getblock_result['tx'][0]['vout']) > 1:
        vouts = getblock_result['tx'][0]['vout']
        for vout in vouts[1:]:
            try:
                addr = vout['scriptPubKey']['addresses'][0]
                if addr in getnotarysendmany_result:
                    getnotarysendmany_result[addr] += 1
                else:
                    print('BUG in the coinbase tx, please report this.')
            except:
                pass
for i in notary_keys:
    score[notary_keys[i]] = getnotarysendmany_result[i]
notaryname = ''
getinfo_result = rpc_connection.getinfo()
if 'notaryname' in getinfo_result:
    notaryname = getinfo_result['notaryname']

total = 0
for i in score:
    total += score[i]

average = int((total / len(score)/4))

s = [(k, score[k]) for k in sorted(score, key=score.get, reverse=True)]
for k, v in s:
    if k == notaryname:
        myscore = str(k) + ' ' + str(v)
        print(lib.colorize(myscore, 'green'))
    elif v < average:
        dropped_NN = str(k) + ' ' + str(v)
        print(lib.colorize(dropped_NN, 'red'))
    else:
        print(k, v)
