#!/usr/bin/env bash

function doIt() {
	rsync --exclude ".git/" \
		--exclude ".DS_Store" \
		--exclude ".osx" \
		--exclude "bootstrap.sh" \
		--exclude "README.md" \
		--exclude "LICENSE-MIT.txt" \
		-avh --no-perms . ~;
	source ~/.zprofile;
}

if [ "$1" = "--force" ] || [ "$1" = "-f" ]; then
	doIt;
else
	echo -e "\033[1;33mThis may overwrite existing files in your home directory. Are you sure? (y/n) \033[0m"
	read REPLY
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		doIt;
	fi;
fi;
unset doIt;