#!/bin/bash
cd ~
sudo apt-get update
sudo apt-get -y install jq htop tmux git slurm bc
git clone https://github.com/StakedChain/SuperNET.git -b staked

