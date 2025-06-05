#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE}")";

git pull origin main;

./git.sh
./brew.sh;
./oh-my-zsh.sh;
./node.sh;
./sync.sh

git_ssh_key
