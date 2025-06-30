#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE}")";

git pull origin main;

./brew.sh;
./oh-my-zsh.sh;
./node.sh;
./sync.sh

git_key_setup
