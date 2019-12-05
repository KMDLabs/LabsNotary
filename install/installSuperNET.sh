#!/bin/bash
cd ~
sudo apt-get update
sudo apt-get -y install jq htop tmux screen git slurm bc dc
git clone https://github.com/KMDLabs/SuperNET.git -b staked
