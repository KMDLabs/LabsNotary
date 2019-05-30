#!/usr/bin/env python3
import os
import re
import json
import http
import time
import bitcoin
import platform
from slickrpc import Proxy
from bitcoin.core import x
from bitcoin.core import CoreMainParams
from bitcoin.wallet import P2PKHBitcoinAddress

class CoinParams(CoreMainParams):
    MESSAGE_START = b'\x24\xe9\x27\x64'
    DEFAULT_PORT = 7770
    BASE58_PREFIXES = {'PUBKEY_ADDR': 60, 'SCRIPT_ADDR': 85, 'SECRET_KEY': 188}
bitcoin.params = CoinParams

NTX_ADDRESS = 'RXL3YXG2ceaB6C5hfJcN4fvmLH2C34knhA'
NN_ADDRESS = 'RSchwBApVquaG6mXH31bQ6P83kMN4Hound'

coins_json = os.getcwd()+'/assetchains.json'
operating_system = platform.system()

if operating_system == 'Darwin':
    ac_dir = os.environ['HOME'] + '/Library/Application Support/Komodo'
elif operating_system == 'Linux':
    ac_dir = os.environ['HOME'] + '/.komodo'
elif operating_system == 'Win64' or operating_system == 'Windows':
    ac_dir = '%s/komodo/' % os.environ['APPDATA']
    import readline

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

def def_creds(chain):
    rpcport ='';
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
            print("check "+coin_config_file)
            exit(1)
    return(Proxy("http://%s:%s@127.0.0.1:%d"%(rpcuser, rpcpassword, int(rpcport))))

def rpc_connect(rpc_user, rpc_password, port):
    try:
        rpc_connection = Proxy("http://%s:%s@127.0.0.1:%d"%(rpc_user, rpc_password, port))
    except Exception:
        raise Exception("Connection error! Probably no daemon on selected port.")
    return rpc_connection

def coins_info(coins_json_file, attrib='ac_name'):
        infolist = []
        with open(coins_json_file) as file:
            assetchains = json.load(file)
        for chain in assetchains:
            infolist.append(chain[attrib])
        return infolist

rpc = {}
for coin in coins_info(coins_json):
	rpc[coin] = def_creds(coin)

def unspent_count(coin):
    count = 0
    dust = 0
    unspent = rpc[coin].listunspent()
    for utxo in unspent:
        if utxo['amount'] == 0.0001:
            count += 1
        elif utxo['amount'] < 0.0001:
            dust += 1
    return [count,dust]

def tx_count(coin):
    return rpc[coin].walletinfo()[tx_count]

def ntx_ranks(coin):
    score = {}
    notary_keys = {}
    print('Please wait while we calculate notarisations ...')
    info = rpc[coin].getinfo()
    height = info['blocks']
    if 'notaryname' in info:
        notaryname = info['notaryname']
    else:
        notaryname = ''

    iguana_json = rpc[coin].getiguanajson()
    for notary in iguana_json['notaries']:
        for i in notary:
            addr = str(P2PKHBitcoinAddress.from_pubkey(x(notary[i])))
            notary_keys[addr] = i

    notarysendmany = rpc[coin].getnotarysendmany()
    for block in range(2,height):
        getblock_result = rpc[coin].getblock(str(block), 2)
        if len(getblock_result['tx'][0]['vout']) > 1:
            vouts = getblock_result['tx'][0]['vout']
            for vout in vouts[1:]:
                try:
                    addr = vout['scriptPubKey']['addresses'][0]
                    if addr in notarysendmany:
                        notarysendmany[addr] += 1
                    else:
                        print('BUG in the coinbase tx, please report this.')
                except Exception as e:
                    pass

    for i in notary_keys:
        score[notary_keys[i]] = notarysendmany[i]

    total = 0
    for i in score:
        total += score[i]

    average = int((total / len(score)/4))

    s = [(k, score[k]) for k in sorted(score, key=score.get, reverse=True)]
    for k, v in s:
        if k == notaryname:
            myscore = str(k) + ' ' + str(v)
            print(colorize(myscore, 'green'))
        elif v < average:
            dropped_NN = str(k) + ' ' + str(v)
            print(colorize(dropped_NN, 'red'))
        else:
            print(k, v)


def last_ntx(coin):
    last_time = 9999999999
    txinfo = rpc[coin].listtransactions("", 77777)
    for tx in txinfo:
        if 'address' in tx:
            if tx['address'] == NTX_ADDRESS:
                time_since = time.time() - tx['time']
                if last_time > time_since:
                    last_time = time_since
    return last_time


for coin in coins_info(coins_json):
    print("==== "+coin+" ====")
    count = unspent_count(coin)
    print(coin+" has "+str(count[0])+" utxos")
    print(coin+" has "+str(count[1])+" dust particles")
    #ntx_ranks(coin)
    print(str(last_ntx(coin))+" sec since NTX")
