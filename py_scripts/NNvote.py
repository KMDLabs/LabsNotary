#!/usr/bin/env python3
import lib
import os
import pprint
import sys
import readline

def test_rpc(chain):
    try:    
        rpc_connection = lib.def_credentials(chain)
        dummy = rpc_connection.getbalance() # test connection
        return(rpc_connection)
    except Exception as e:
        print(e)
        error = 'Error: Could not connect to daemon. ' + chain + ' is not running or rpc creds not found.'
        print(error)
        sys.exit(0)


def print_menu(menu_list, chain, msg, init):
    if isinstance(msg, dict) or isinstance(msg, list):
        pprint.pprint(msg)
    else: 
        if str(msg[:5]) == 'Error':
            print(lib.colorize(msg, 'red'))
        else:
            print(lib.colorize(msg, 'green'))
    print(lib.colorize('\n' + chain, 'magenta'))
    sync = lib.is_chain_synced(chain)
    if sync != 0:
        print(lib.colorize('chain not in sync ' + str(sync), 'red'))
    print(lib.colorize('===============', 'blue'))
    menu_item = 0
    if not init:
        menu_item = 1
        print('0 | <return to previous menu>\n')
    for i in menu_list:
        print(str(menu_item) + ' | ' + str(i))
        menu_item += 1
    print('\nq | Exit TUI')
    print(lib.colorize('===============\n', 'blue'))


def initial_loop(chain, msg):
    os.system('clear')
    rpc_connection = test_rpc(chain)
    while True:
        os.system('clear')
        print_menu(initial_menu, chain, msg, True)
        selection = lib.user_inputInt(0,len(initial_menu)-1,"make a selection:")
        if int(selection) == 0:
            msg = vote_loop('LABS', '')
            vote_loop(chain, msg)
        elif int(selection) == 1:
            msg = lottery_loop('LABS', '')
            vote_loop(chain, msg)


def lottery_loop(chain, msg):
    # lottery oracle txid is hardcoded for now
    # will revist this when it's time to do another
    oracle = {'txid': '0c1102054003a742f0fe09d990c5b2f1e4ced350021e76b62eada7092dafac37',
              'deadline': 1572202066}
    os.system('clear')
    rpc_connection = test_rpc(chain)
    while True:
        os.system('clear')
        print_menu(lottery_menu, chain, msg, False)
        selection = lib.user_inputInt(0,len(lottery_menu)+1,"make a selection:")
        if int(selection) == 0:
            initial_loop(chain, '')
        elif int(selection) == 1:
            msg = ('1. Securely create an address. This address will be your notary node address.\n' +
                  '2. Start the LABS daemon with -pubkey for this address.\n'  + 
                  '3. Select \"Register for lottery\". This will output a txid. Wait for this to confirm.\n' +
                  '4. Select \"Join lottery\". This will ask you for your handle. It will also ask you to input'  +
                  ' a message. This message can be anything you choose, consider it choosing numbers for a lottery\n' +
                  '5. Select \"Create signed message\". This will output a signed messaged.' +
                  ' You must add this to the participants.json file of the LabsNotary repo and send a pull request.' + 
                  ' You must also post this to the #kmdlabs'  +
                  ' channel in the KMD discord. \n\nPlease note, you must do all of this prior to the deadline.' +
                  ' There are absolutely no exceptions to this as the deadline is when the entropy is revealed.')
            lottery_loop(chain, msg)
        elif int(selection) == 2:
            msg = lib.lottery_participants(rpc_connection, oracle)
            lottery_loop(chain, msg)
        elif int(selection) == 3:
            msg = lib.vote_register(rpc_connection, oracle)
            lottery_loop(chain, msg)
        elif int(selection) == 4:
            msg = lib.lottery_join(rpc_connection, oracle)
            lottery_loop(chain, msg)
        elif int(selection) == 5:
            msg = lib.lottery_sign(rpc_connection, oracle)
            lottery_loop(chain, msg)
        elif int(selection) == 6:
            msg = lib.lottery_verify(rpc_connection, oracle)
            lottery_loop(chain, msg)


def vote_loop(chain, msg):
    os.system('clear')
    rpc_connection = test_rpc(chain)
    while True:
        os.system('clear')
        print_menu(vote_menu, chain, msg, False)
        selection = lib.user_inputInt(0,len(vote_menu),"make a selection:")
        if int(selection) == 0:
            initial_loop(chain, '')
        elif int(selection) == 1:
            msg = lib.list_polls(rpc_connection, True)
            vote_loop(chain, msg)
        elif int(selection) == 2:
            msg = vote_selection(chain, '', 'register')
            vote_loop(chain, msg)
        elif int(selection) == 3:
            msg = vote_selection(chain, '', 'vote')
            vote_loop(chain, msg)
        elif int(selection) == 4:
            msg = vote_selection(chain, '', 'view results')
            vote_loop(chain, msg)
        elif int(selection) == 5:
            msg = lib.create_poll(rpc_connection)
            vote_loop(chain, msg)
        elif int(selection) == 6:
            msg = lib.list_polls(rpc_connection, False)
            vote_loop(chain, msg)

def vote_selection(chain, msg, reg_or_vote):
    os.system('clear')
    rpc_connection = test_rpc(chain)
    active_polls = lib.list_polls(rpc_connection, True)
    if not active_polls:
        vote_loop(chain, 'Error: no polls found')
    if str(active_polls).startswith('Error'):
        vote_loop(chain, str(active_polls))
    os.system('clear')
    print_menu(active_polls, chain, 'Please select a poll to ' + reg_or_vote, True)
    selection = lib.user_inputInt(0,len(active_polls)-1,"make a selection:")
    if reg_or_vote == 'vote':
        msg = option_selection(chain, active_polls[selection])
    elif reg_or_vote == 'register':
        msg = lib.vote_register(rpc_connection, active_polls[selection])
    elif reg_or_vote == 'view results':
        msg = lib.vote_results(rpc_connection, active_polls[selection])
    vote_loop(chain, msg)

def option_selection(chain, poll): 
    os.system('clear')
    rpc_connection = test_rpc(chain)
    options = poll['options']
    options.append('subjective')
    print_menu(options, chain, poll['question'] + '\nPlease select your position.', True)
    selection = lib.user_inputInt(0,len(options)-1,"make a selection:")
    msg = lib.vote(rpc_connection, options[selection], poll['txid'])
    vote_loop(chain, msg)

initial_menu = ['NN voting', 'NN lottery']
vote_menu = ['List active polls', 'Register to vote', 'Vote', 'Voting results', 'Create new poll', 'List previous polls']
lottery_menu = ['How to participate', 'View participants', 'Register for lottery','Join lottery', 'Create signed message','Verify results']


initial_loop('LABS', '')
