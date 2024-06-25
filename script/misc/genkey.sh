#!/bin/bash

# Check if go version is less than v18
if [[ "$(go version | awk '{print $3}' | cut -c 3-)" < "1.18" ]]; then
    echo "Go version must be at least v18"
    exit 1
fi

# Set the log file path
# Execute the command and capture its output
output=$(./bin/ronin-random-beacon generate-key 2>&1)
# Extract the generated public key using grep and awk
public_key=$(echo "$output" | grep 'Generated public key is:' | awk -F': ' '{print $2}' | awk '{print $1}')
# Extract the key hash using grep and awk
key_hash=$(echo "$output" | grep 'Key hash is:' | awk -F': ' '{print $2}')
# Extract the secret key using grep and awk
secret_key=$(echo "$output" | grep 'Secret key is:' | awk -F': ' '{print $2}')

echo $public_key,$key_hash,$secret_key
