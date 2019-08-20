#!/bin/bash

#temporary
type dc>/dev/null 2>&1 || sudo apt-get install dc

cd $HOME/StakedNotary
checkRepo () {
    if [ -z $1 ]; then
      return
    fi
    prevdir=${PWD}
    if [[ ! -f komodo/$1/lastbuildcommit ]]; then
      eval cd "$HOME/komodo"
      git pull > /dev/null 2>&1
      git checkout $1 > /dev/null 2>&1
      localrev=$(git rev-parse HEAD)
      mkdir -p $HOME/StakedNotary/komodo/$1
      echo $localrev > $HOME/StakedNotary/komodo/$1/lastbuildcommit
      cd $prevdir
    fi
    localrev=$(cat komodo/$1/lastbuildcommit)
    eval cd "$HOME/komodo"
    git remote update > /dev/null 2>&1
    remoterev=$(git rev-parse origin/$1)
    cd $prevdir
    echo "[$1] Komodod local_commit: $localrev vs remote_commit: $remoterev"
    if [ $localrev != $remoterev ]; then
      return 1
    else
      return 0
    fi
}

buildkomodo () {
  if [ -z $1 ]; then
    return
  fi
  cd $HOME/komodo
  git pull > /dev/null 2>&1
  git checkout $1  > /dev/null 2>&1
  git pull  > /dev/null 2>&1
  rm -f $HOME/komodo/src/komodod $HOME/komodo/src/komodo-cli > /dev/null 2>&1
  #make clean > /dev/null 2>&1
  #make -j$(nproc) > /dev/null 2>&1
  ./zcutil/build.sh -j$(nproc) > /dev/null 2>&1
  if [[ ! -f $HOME/komodo/src/komodod ]]; then
    return 0
  fi
  if [[ ! -f $HOME/komodo/src/komodo-cli ]]; then
    return 0
  fi
  localrev=$(git rev-parse HEAD)
  mkdir -p $HOME/StakedNotary/komodo/$1
  echo $localrev > $HOME/StakedNotary/komodo/$1/lastbuildcommit
  mv src/komodod $HOME/StakedNotary/komodo/$1
  mv src/komodo-cli $HOME/StakedNotary/komodo/$1
  return 1
}

if [ -z $1 ]; then
  exit
fi

branch=$1

checkRepo $branch
outcome=$(echo $?)

if [[ $outcome = 1 ]] || [[ ! -f komodo/$1/komodod ]] || [[ ! -f komodo/$1/komodo-cli ]]; then
  buildkomodo $branch
  outcome=$(echo $?)
  if [[ $outcome = 1 ]]; then
    echo "updated"
  else
    echo "update_failed"
  fi
fi
