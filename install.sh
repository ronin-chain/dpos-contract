#!/bin/bash

# Check if foundry is installed
if ! command -v forge &>/dev/null; then
    # Install foundryup
    curl -L https://foundry.paradigm.xyz | bash
    # Install foundry
    $HOME/.foundry/bin/foundryup

    $HOME/.foundry/bin/forge soldeer update
    # Run forge build
    $HOME/.foundry/bin/forge build
fi

# Check if jq is installed
if ! command -v jq &>/dev/null; then
    # Install jq
    sudo apt-get install jq
fi

# Check if yq is installed
if ! command -v yq &>/dev/null; then
    curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/bin/yq &&
        sudo chmod +x /usr/bin/yq
fi

# Check if gvm is installed
if ! command -v go &>/dev/null; then
    # Install bison
    sudo apt-get install bison
    # Install gvm
    bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
    # Source gvm script
    source $HOME/.gvm/scripts/gvm
    sudo apt-get install bsdmainutils

    # Install go1.19
    gvm install go1.19 -B
fi

rm -rf temp && mkdir temp && cd temp

git clone https://github.com/ronin-chain/ronin-random-beacon.git && cd ronin-random-beacon

# Check if installed gvm
if ! command -v gvm &>/dev/null; then
    gvm use go1.19
fi

go build -o ronin-random-beacon && cp ronin-random-beacon ../../bin/ && cd ../../ && rm -rf temp
