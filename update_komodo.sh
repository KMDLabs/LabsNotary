#!/bin/bash
cd $HOME/StakedNotary
checkRepo () {
    if [ -z $1 ]; then
      return
    fi
    prevdir=${PWD}
    if [[ ! -f komodo/$1/lastbuildcommit ]]; then
      eval cd "$HOME/komodo"
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
  branch=$1
  cd $HOME/komodo
  git pull > /dev/null 2>&1
  git checkout $1  > /dev/null 2>&1
  git pull  > /dev/null 2>&1
  make clean > /dev/null 2>&1
  make -j$(nproc) > /dev/null 2>&1
  if [[ ! -f $HOME/komodo/src/komodod ]]; then
    return 0
  fi
  if [[ ! -f $HOME/komodo/src/komodo-cli ]]; then
    return 0
  fi
  localrev=$(git rev-parse HEAD)
  mkdir -p $HOME/StakedNotary/komodo/$1
  echo $localrev > $HOME/StakedNotary/komodo/$1/lastbuildcommit
  mv src/komodod $HOME/StakedNotary/$1
  mv src/komodo-cli $HOME/StakedNotary/$1
  return 1
}

if [ -z $1 ]; then
  exit
fi

branch=$1

checkRepo $branch
outcome=$(echo $?)

if [[ $outcome = 1 ]]; then
  buildkomodo $branch
  outcome=$(echo $?)
  if [[ $outcome = 1 ]]; then
    echo "updated"
  else
    echo "update_failed"
  fi
else
  echo "no_update"
fi
