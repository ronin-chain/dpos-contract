#!/bin/bash

# Check if go version is less than v18
if [[ "$(go version | awk '{print $3}' | cut -c 3-)" < "1.18" ]]; then
    echo "Go version must be at least v18"
    exit 1
fi

# Set the log file path
log_file="logs/temp.log"
./bin/ronin-random-beacon generate-key &> $log_file;

# Extract the generated public key, key hash, and secret key using grep and awk
public_key=$(grep "Generated public key is" "$log_file" | awk '{print $7}')
key_hash=$(grep "Key hash is:" "$log_file" | awk '{print $6}')
secret_key=$(grep "Secret key is:" "$log_file" | awk '{print $6}')

echo $public_key,$key_hash,$secret_key