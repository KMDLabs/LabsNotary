#!/bin/bash
cecho() {
  local code="\033["
  case "$1" in
    red    |  r) color="${code}1;31m";;
    green  |  g) color="${code}1;32m";;
    yellow |  y) color="${code}1;33m";;
    blue   |  b) color="${code}1;34m";;
    purple |  p) color="${code}1;35m";;
    cyan   |  c) color="${code}1;36m";;
    gray   | gr) color="${code}0;37m";;
    *) local text="$1"
  esac
  [ -z "$text" ] && local text="$color$2${code}0m"
  echo -n -e "$text"
}

calc() {
  awk "BEGIN { print "$*" }"
}

total=0

./listassetchains.py | while read coin; do
  supply=$(komodo-cli -ac_name=$coin coinsupply | jq -r .total)
  if [[ $supply != "" ]]; then
    cecho g "[$coin]"; cecho b "$supply\n"
    total=$(calc "${total}+${supply}")
  fi
done

cecho r "[TOTAL]"; cecho c "$total\n"
