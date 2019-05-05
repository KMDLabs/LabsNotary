#!/usr/bin/env python3
import lib
import os
import pprint
import sys

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


def print_menu(menu_list, chain, msg):
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
    for i in menu_list:
        print(str(menu_item) + ' | ' + str(i))
        menu_item += 1
    print('\nq | Exit TUI')
    print(lib.colorize('===============\n', 'blue'))


def vote_loop(chain, msg):
    os.system('clear')
    rpc_connection = test_rpc(chain)
    while True:
        os.system('clear')
        print_menu(vote_menu, chain, msg)
        selection = lib.user_inputInt(0,len(vote_menu),"make a selection:")
        if int(selection) == 0:
            msg = lib.list_active_polls(rpc_connection)
            vote_loop(chain, msg)
        elif int(selection) == 1:
            msg = vote_selection(chain, '', 'register')
            vote_loop(chain, msg)
        elif int(selection) == 2:
            msg = vote_selection(chain, '', 'vote')
            vote_loop(chain, msg)
        elif int(selection) == 3:
            msg = 'ok'
            vote_loop(chain, msg)
        elif int(selection) == 4:
            msg = lib.create_poll(rpc_connection)
            vote_loop(chain, msg)

def vote_selection(chain, msg, reg_or_vote):
    os.system('clear')
    rpc_connection = test_rpc(chain)
    active_polls = lib.list_active_polls(rpc_connection)
    if str(active_polls).startswith('Error'):
        vote_loop(chain, str(active_polls))
    os.system('clear')
    print_menu(active_polls, chain, 'Please select a poll to ' + reg_or_vote)
    selection = lib.user_inputInt(0,len(active_polls)-1,"make a selection:")
    if reg_or_vote == 'vote':
        msg = option_selection(chain, active_polls[selection])
    elif reg_or_vote == 'register':
        msg = lib.vote_register(rpc_connection, active_polls[selection])
    vote_loop(chain, msg)

def option_selection(chain, poll): 
    os.system('clear')
    rpc_connection = test_rpc(chain)
    options = poll['options']
    options.append('subjective')
    print_menu(options, chain, poll['question'] + '\nPlease select your position.')
    selection = lib.user_inputInt(0,len(options)-1,"make a selection:")
    msg = lib.vote(rpc_connection, options[selection], poll['txid'])
    vote_loop(chain, msg)
    
vote_menu = ['List active polls', 'Register to poll', 'Vote', 'Voting results', 'Create new poll']

vote_loop('CFEKORC', '')
