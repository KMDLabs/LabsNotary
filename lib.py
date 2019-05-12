#!/usr/bin/env python3
import json
import re
import os
import platform
import sys
import ast
import codecs
import readline
from datetime import datetime
from slickrpc import Proxy
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


# define data dir
def def_data_dir():
    operating_system = platform.system()
    if operating_system == 'Darwin':
        ac_dir = os.environ['HOME'] + '/Library/Application Support/Komodo'
    elif operating_system == 'Linux':
        ac_dir = os.environ['HOME'] + '/.komodo'
    elif operating_system == 'Windows':
        ac_dir = '%s/komodo/' % os.environ['APPDATA']
    return(ac_dir)


# fucntion to define rpc_connection
def def_credentials(chain):
    rpcport = '';
    ac_dir = def_data_dir()
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


def is_chain_synced(chain):
    rpc_connection = def_credentials(chain)
    getinfo_result = rpc_connection.getinfo()
    blocks = getinfo_result['blocks']
    longestchain = getinfo_result['longestchain']
    if blocks == longestchain:
        return(0)
    else:
        return([blocks, longestchain])


def user_inputInt(low,high, msg):
    while True:
        user_input = input(msg)
        if user_input == ('q' or 'quit'):
            print('Exiting...')
            sys.exit(0)
        try:
            number = int(user_input)
        except ValueError:
            print("integer only, try again")
            continue
        if low <= number <= high:
            return number
        else:
            print("input outside range, try again")



def notary_list(rpc):
    iguana_json = rpc.getiguanajson()
    notary_list = []
    for notary in iguana_json['notaries']:
        templist = []
        for i in notary:
            templist.append(i)
            templist.append(notary[i])
            notary_list.append(templist)
    return(notary_list) 


def vote_results(rpc, poll):
    notarylist = notary_list(rpc)
    NN_pks = []
    result = {}
    pubkey_name = {}
    for notary in notarylist:
        pubkey_name[notary[1]] = notary[0]
        result[notary[0]] = 'unanswered'
        NN_pks.append(notary[1])

    # get baton address for NN pubkeys that have registered
    voted = {}
    oraclesinfo = rpc.oraclesinfo(poll['txid'])
    for reg in oraclesinfo['registered']:
        if reg['publisher'] in NN_pks:
            if not reg['batontxid'] in voted:
                voted[reg['publisher']] = reg['baton']

    votes = {}
    for baton_addr in voted:
        time_sample = {}
        times = []
        orcl_txids = rpc.getaddresstxids(voted[baton_addr], '1')

        # iterate over baton address, find oldest sample
        for orcl_txid in orcl_txids:
            rawtx = rpc.getrawtransaction(orcl_txid, 2)
            if rawtx['vout'][-1]['scriptPubKey']['type'] == 'nulldata':
                opret = rawtx['vout'][-1]['scriptPubKey']['hex']
                decode_opret = rpc.decodeccopret(opret)
                try:
                    if decode_opret['OpRets'][0]['eval_code'] == 'EVAL_ORACLES' and decode_opret['OpRets'][0]['function'] == 'D':
                        # additional check to prevent impersonation
                        input_addrs = []
                        for vin in rawtx['vin']:
                            input_addrs.append(vin['address'])
                        if not voted[baton_addr] in input_addrs:
                            continue

                        sample = rpc.oraclessamples(poll['txid'], orcl_txid, '1')
                        if sample['samples']:
                            if rawtx['blocktime'] < poll['deadline']:
                                times.append(rawtx['blocktime'])
                                times.sort()
                                time_sample[rawtx['blocktime']] = sample['samples']
                                votes[baton_addr] = time_sample[times[0]]
                except Exception as e:
                    continue

    for pubkey in votes:
        result[pubkey_name[pubkey]] = votes[pubkey][0][0]

    return(result)


def list_polls(rpc, active):
    try:
        mypk = rpc.setpubkey()['pubkey']
    except:
        return('Error: -pubkey not set')

    notarylist = notary_list(rpc)
    NN_pks = []
    for notary in notarylist:
        NN_pks.append(notary[1])

    oracles = rpc.oracleslist()
    polls_done = []
    polls_active = []
    current_time = rpc.getinfo()['tiptime']
    for oracle in oracles:
        vote_info = {}
        publishers = []
        oracleinfo = rpc.oraclesinfo(oracle)
        oraclecreate_decode = rpc.getrawtransaction(oracle, 2)

        if oracleinfo['name'][-4:] == 'VOTE':
            # check that signed message matches key
            sig = oracleinfo['description'][:88]
            msg = oracleinfo['description'][88:]
            try:
                desc_dict = ast.literal_eval(msg)
            except:
                continue

            try:
                creator_pk = desc_dict['pk']
                creator_addr = P2PKHBitcoinAddress.from_pubkey(x(creator_pk))
            except Exception as e:
                continue

            try:
                verify = rpc.verifymessage(str(creator_addr), sig, msg)
            except:
                continue
            if not verify:
                continue

            # check that the key is a notary
            if creator_pk in NN_pks:
               vote_info['name'] = oracleinfo['name'][:-5]
               vote_info['question'] = desc_dict['question']
               vote_info['options'] = desc_dict['options']
               vote_info['created'] = oraclecreate_decode['blocktime']
               vote_info['deadline'] = oraclecreate_decode['blocktime'] + 604800 # 1 week, arbitrary limit could be dynamic
               vote_info['txid'] = oracle
               for i in notarylist:
                   if i[1] == creator_pk:
                       creator = i[0]
               vote_info['creator'] = creator
               if current_time < vote_info['deadline']:
                       polls_active.append(vote_info)
               else:
                       polls_done.append(vote_info)
                   
    if active:
        return(polls_active)
    else:
        return(polls_done)
    


def create_poll(rpc):
    try:
        mypk = rpc.setpubkey()['pubkey']
    except:
        return('Error: -pubkey not set')
    mypk_addr = rpc.setpubkey()['address']

    notarylist = notary_list(rpc)
    NN_pks = []
    for notary in notarylist:
        NN_pks.append(notary[1])
    if not mypk in NN_pks:
        return('Error: -pubkey is not a notary pubkey.')

    print('Please be as objective as possible. ' +
          '>50% of notaries must vote for a change for it to be implemented. '+ 
          'A notary can also vote \"subjective\" to signify ' +
          'they believe poll question should be clarified and reasked. ' +
          'Polls will have a voting deadline of 1 week for now.\n')

    options = []
    option_count = user_inputInt(1,10, 'Please input the number of options for the poll. '
                                       'This number does not include the \"subjective\" option: ')
    poll_name = str(input('Please input a name for this poll: ')) + '_VOTE'
    question = input('Please input the full question you wish to ask. Be as clear and objective as possible: ')
    for i in range(option_count):
        options.append(input('Please input option ' + str(i) + ': '))
    
    description = {}
    description['question'] = question
    description['options'] = options
    description['pk'] = mypk
    print('\nname:', poll_name)
    print(description)
    yn = input('\nPlease confirm this is correct(y/n):')
    if not yn.startswith('y'):
        return('Cancelled poll creation')
    
    # create a signed message from notary key to prevent impersonation
    signed = rpc.signmessage(mypk_addr, str(description))

    try:
        oraclescreate = rpc.oraclescreate(poll_name, signed + str(description), 'S')
    except Exception as e:
        return('Error: oraclescreate rpc command failed with ' + str(e))

    try:
        create_hex = oraclescreate['hex']
    except Exception as e:
        return('Error: oraclescreate rpc command failed with ' + str(oraclescreate))

    txid = rpc.sendrawtransaction(create_hex)
    return('Success! Poll created at ' + txid )
    
def oraclesdata_encode(message):
    rawhex = codecs.encode(message).hex()

    #get length in bytes of hex in decimal
    bytelen = int(len(rawhex) / int(2))
    hexlen = format(bytelen, 'x')

    #get length in big endian hex
    if bytelen < 16:
        bigend = "000" + str(hexlen)
    elif bytelen < 256:
        bigend = "00" + str(hexlen)
    elif bytelen < 4096:
        bigend = "0" + str(hexlen)
    elif bytelen < 65536:
        bigend = str(hexlen)

    #convert big endian length to little endian, append rawhex to little endian length
    lilend = bigend[2] + bigend[3] + bigend[0] + bigend[1]
    fullhex = lilend + rawhex
    return(fullhex)


def vote_register(rpc, poll):
    txid = poll['txid']
    oracleinfo = rpc.oraclesinfo(txid)
    try:
        mypk = rpc.setpubkey()['pubkey']
    except Exception as e:
        return('Error: -pubkey is not set' + str(e))

    # register to poll oracle
    try:
        oraclereg = rpc.oraclesregister(txid, '10000')
    except Exception as e:
        return('Error: oraclesregister rpc command failed with ' + str(e))
    try:
        oraclereg_hex = oraclereg['hex']
    except Exception as e:
        return('Error: oraclesregister rpc command failed with ' + str(oraclereg))
    reg_txid = rpc.sendrawtransaction(oraclereg_hex)

    # subscribe to self on poll oracle
    try:
        oraclesub = rpc.oraclessubscribe(txid, mypk, '0.00010000')
    except Exception as e:
        return('Error: oraclessubscribe rpc command failed with ' + str(e))
    try:
        sub_hex = oraclesub['hex']
    except:
        return('Error: oraclessubscribe rpc command failed with ' + str(oraclesub))

    sub_txid = rpc.sendrawtransaction(sub_hex)
    return('Success! Please wait for ' + sub_txid + ' to be confirmed.')



def vote(rpc, option, txid):
    try:
        mypk = rpc.setpubkey()['pubkey']
    except Exception as e:
        return('Error: -pubkey is not set' + str(e))

    if option == 'subjective':
        option += ':' + str(input('Please specify why you believe this question' +
                           ' is subjective and should be reasked: '))

    oracleinfo = rpc.oraclesinfo(txid)
    publishers = []
    for pub in oracleinfo['registered']:
        publishers.append(pub['publisher'])
    
    if not mypk in publishers:
        return('Error: You must register to this poll before voting. ' + 
               'The register txid must be confirmed as well.')

    oracle_hex = oraclesdata_encode(option)
    try:
        oraclesdata = rpc.oraclesdata(txid, oracle_hex)
    except Exception as e:
        return('Error: oraclesdata rpc command failed with ' + str(e))

    try:
        data_hex = oraclesdata['hex']
    except Exception as e:
        return('Error: oraclesdata rpc command failed with ' + str(oraclesdata))


    yn = input('You selected \"' + option + '\" for the poll, \"' + oracleinfo['name'][:-5] + 
          '\"\nPlease confirm this is correct(y/n): ')
    if not yn.startswith('y'):
        return('Vote cancelled. Try again.')
    
    oraclesdata_txid = rpc.sendrawtransaction(data_hex)

    return('Success! You voted \"' + option + '\"\n' + 'txid: ' + oraclesdata_txid)


def lottery_join(rpc, oracle):
    try:
        mypk = rpc.setpubkey()['pubkey']
    except Exception as e:
        return('Error: -pubkey is not set' + str(e))

    oraclesinfo = rpc.oraclesinfo(oracle['txid'])

    publisher_pks = []
    for publisher in oraclesinfo['registered']:
        publisher_pks.append(publisher['publisher'])

    if not mypk in publisher_pks:
        return('Error: Please use the \"Register for lottery\". You must also wait for at least 1 confirmation')

    handle = input('Please input your name/handle. This will be used in ' + 
                   'the source code, so please take it seriously: ')

    ticket = input('Please input a message. This can be thought of ' + 
                   'as choosing lottery numbers. It can be anything you like: ')
    
    oracle_payload = {handle: ticket}
    oracle_hex = oraclesdata_encode(str(oracle_payload))
    try:
        oraclesdata = rpc.oraclesdata(oracle['txid'], oracle_hex)
    except Exception as e:
        return('Error: oraclesdata rpc command failed with ' + str(e))

    try:
        data_hex = oraclesdata['hex']
    except Exception as e:
        return('Error: oraclesdata rpc command failed with ' + str(oraclesdata))

    print(oracle_payload)
    yn = input('Please confirm this is correct. This cannot be changed. ' +
               'Only the first entry will be considered valid(y/n): ')
    if not yn.startswith('y'):
        return('Cancelled. Try again.')

    oraclesdata_txid = rpc.sendrawtransaction(data_hex)

    return('Success! You must now use \"Create signed message\" option ' + 
           'and post the result to both github and discord!\n' + oraclesdata_txid)


def lottery_participants(rpc, oracle):
    try:
        mypk = rpc.setpubkey()['pubkey']
    except Exception as e:
        return('Error: -pubkey is not set' + str(e))

    oraclesinfo = rpc.oraclesinfo(oracle['txid'])

    pubkey_baton = {}
    for reg in oraclesinfo['registered']:
        pubkey_baton[reg['publisher']] = reg['baton']


    participants = []
    for part in pubkey_baton:
        times = []
        time_sample = {}
        pk_addr = P2PKHBitcoinAddress.from_pubkey(x(part))
        orcl_txids = rpc.getaddresstxids(pubkey_baton[part], '1')
        for txid in orcl_txids:
            rawtx = rpc.getrawtransaction(txid, 2)
            try:
                blocktime = rawtx['blocktime']
            except:
                continue
            input_addrs = []
            for vin in rawtx['vin']:
                input_addrs.append(vin['address'])

            # check that someone didn't send an oraclesdata to someone else's baton addr
            if not str(pk_addr) in input_addrs and not pubkey_baton[part] in input_addrs:
                continue

            samples = rpc.oraclessamples(oracle['txid'], txid, '0')
            if samples['samples']:
                times.append(blocktime)
                time_sample[blocktime] = samples['samples'][0][0]
            else:
                continue

        times.sort()
        if times:
            participants.append([time_sample[times[0]], part])

    return(participants)


# FIXME needs a try to see if already joined
def lottery_sign(rpc, oracle):
    try:
        setpubkey = rpc.setpubkey()
        mypk = setpubkey['pubkey']
    except Exception as e:
        return('Error: -pubkey is not set ' + str(e))

    participants = lottery_participants(rpc, oracle)
    for part in participants:
        print(part)
        if mypk == part[1]:
            try:
                signed_msg = rpc.signmessage(setpubkey['address'], part[0])
            except Exception as e:
                return('Error: signmessage rpc command failed with ' + str(e))

    return('The following message must be included in a pull request to the ' + 
           'participants.json file in the StakedNotary repo.\n\n' + 
           signed_msg + part[0])



