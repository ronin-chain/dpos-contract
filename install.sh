#!/bin/bash

# Check if foundry is installed
if ! command -v $HOME/.foundry/bin/forge &>/dev/null; then
    # Install foundryup
    curl -L https://foundry.paradigm.xyz | bash
    # Install foundry
    $HOME/.foundry/bin/foundryup
fi

$HOME/.foundry/bin/forge soldeer update
# Run forge build
$HOME/.foundry/bin/forge build

# Check if homebrew is installed
if ! command -v brew &>/dev/null; then
    # Install homebrew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Check if jq is installed
if ! command -v jq &>/dev/null; then
    # Install jq
    brew install jq
fi

# Check if yq is installed
if ! command -v yq &>/dev/null; then
    # Install yq
    brew install yq
fi

# Check if gvm is installed
if ! command -v gvm &>/dev/null; then
    # Install bison
    brew install bison
    # Install gvm
    bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
fi

# Source gvm script
source ~/.gvm/scripts/gvm
# Install go1.19
gvm install go1.19 -B

rm -rf temp
mkdir temp
cd temp
ls

git clone git@github.com:ronin-chain/ronin-random-beacon.git

cd ronin-random-beacon

gvm use go1.19 && go build -o ronin-random-beacon

cp ronin-random-beacon ../../bin/ && cd ../../

rm -rf temp
