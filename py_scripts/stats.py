#!/usr/bin/env python3
import lib
import sys
import time

CHAIN = input('Please specify chain: ')
try:
   rpc_connection = lib.def_credentials(CHAIN)
except:
   print(CHAIN + ' daemon is not running or RPC creds not found')
   sys.exit(0)

try:
    block_range = int(input('Please specify amount of previous blocks(0 for all): '))
except:
    print('Blocks must be whole number. Exiting...')
    sys.exit(0)

nn_names = []
iguana_json = rpc_connection.getiguanajson()
for notary in iguana_json['notaries']:
    for notaryname in notary.keys():
        nn_names.append(str(notaryname))

mynotaryname = ''
getinfo_result = rpc_connection.getinfo()
if 'notaryname' in getinfo_result:
    mynotaryname = getinfo_result['notaryname']

timestamp = int(time.time())
notary_counts = {}
blockheight = getinfo_result['blocks']
start_at = blockheight - block_range
if start_at < 0:
        start_at = 1
for x in range(start_at, blockheight):
    resp = rpc_connection.getNotarisationsForBlock(x)
    for ac in resp['LABS']:
        if 'chain' in ac and ac['chain'] == CHAIN:
            for notary in ac['notaries']:
                if str(notary) not in notary_counts:
                    notary_counts.update({str(notary):0})
                count = notary_counts[str(notary)]+1
                notary_counts.update({str(notary):count})

n=0
for notary, score in sorted(notary_counts.items(), key=lambda x: x[1], reverse=True):
    notaryname = nn_names[n]
    n = n + 1
    if notaryname == mynotaryname:
        myscore = str(notaryname) + ' ' + str(score)
        print(lib.colorize(myscore, 'green'))
    else:
        print(notaryname, score)
