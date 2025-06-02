#!/usr/bin/env bash

# Install command-line tools using Homebrew.

# Check if Homebrew is installed
if ! command -v brew &>/dev/null; then
	echo "Homebrew not found. Installing Homebrew..."
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
	echo "Homebrew is already installed. Proceeding..."
fi

# Make sure we’re using the latest Homebrew.
brew update

# Upgrade any already-installed formulae.
brew upgrade

# Save Homebrew’s installed location.
BREW_PREFIX=$(brew --prefix)

# Install GNU core utilities (those that come with macOS are outdated).
# Don’t forget to add `$(brew --prefix coreutils)/libexec/gnubin` to `$PATH`.
brew install coreutils
ln -s "${BREW_PREFIX}/bin/gsha256sum" "${BREW_PREFIX}/bin/sha256sum"

# Install some other useful utilities like `sponge`.
brew install moreutils
# Install GNU `find`, `locate`, `updatedb`, and `xargs`, `g`-prefixed.
brew install findutils
# Install GNU `sed`, overwriting the built-in `sed`.
brew install gnu-sed --with-default-names
# Install a modern version of Zsh.
brew install zsh

# Install wget and curl.
brew install wget
brew install curl

# Install more recent versions of some macOS tools.
brew install vim --with-override-system-vi
brew install grep
brew install openssh
brew install screen

# Install font tools.
brew tap bramstein/webfonttools
brew install --cask font-powerline-symbols

# Install other useful binaries.
brew install git
brew install git-lfs
brew install ossp-uuid

# Install terminal tools.
brew install fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Applications.
brew install --cask chrome
brew install --cask visual-studio-code
brew install --cask github
brew install --cask spotify
brew install --cask postman
brew install --cask docker
brew install --cask slack

# Development
## Go
brew install go

## Node
brew install node
brew install nvm
brew install pnpm

# Remove outdated versions from the cellar.
brew cleanup
