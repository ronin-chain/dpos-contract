# Install foundryup
curl -L https://foundry.paradigm.xyz | bash
# Install foundry
$HOME/.foundry/bin/foundryup -v nightly-de33b6af53005037b463318d2628b5cfcaf39916 # Stable version
# Install rustup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
# Update rustup
$HOME/.cargo/bin/rustup update stable
# Install soldeer
$HOME/.cargo/bin/cargo install soldeer
# Update dependencies with soldeer
$HOME/.cargo/bin/soldeer update
# Run forge build
$HOME/.foundry/bin/forge build
# Install jq
brew install jq
# Install yq
brew install yq