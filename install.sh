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
    brew install jq
fi

# Check if yq is installed
if ! command -v yq &>/dev/null; then
    brew install -y wget
    sudo wget https://github.com/mikefarah/yq/releases/download/v4.34.1/yq_linux_amd64 -O /usr/local/bin/yq
    sudo chmod +x /usr/local/bin/yq
fi

# Check if gvm is installed
if ! command -v gvm &>/dev/null; then
    # Install bison
    brew install bison
    # Install gvm
    bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
    # Source gvm script
    source $HOME/.gvm/scripts/gvm
    brew install bsdmainutils

    # Install go1.19
    gvm install go1.19 -B
fi

rm -rf temp && mkdir temp && cd temp && git clone https://github.com/ronin-chain/ronin-random-beacon.git && cd ronin-random-beacon

# Check if installed gvm
if ! command -v gvm &>/dev/null; then
    gvm use go1.19
fi

go build -o ronin-random-beacon && cp ronin-random-beacon ../../bin/ && cd ../../ && rm -rf temp

echo "Installed successfully!"
