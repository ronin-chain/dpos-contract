#!/bin/bash

# Set the log file path
log_file="logs/temp.log"
./ronin-random-beacon generate-key &> $log_file;

# Extract the generated public key, key hash, and secret key using grep and awk
public_key=$(grep "Generated public key is" "$log_file" | awk '{print $7}')
key_hash=$(grep "Key hash is:" "$log_file" | awk '{print $6}')
secret_key=$(grep "Secret key is:" "$log_file" | awk '{print $6}')

echo $public_key,$key_hash,$secret_key