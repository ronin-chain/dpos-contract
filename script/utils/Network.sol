// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibString, TNetwork } from "foundry-deployment-kit/types/Types.sol";

enum Network {
  Goerli,
  EthMainnet,
  RoninDevnet
}

using { key, name, chainId, chainAlias, envLabel, deploymentDir, explorer } for Network global;

function chainId(Network network) pure returns (uint256) {
  if (network == Network.Goerli) return 5;
  if (network == Network.EthMainnet) return 1;
  if (network == Network.RoninDevnet) return 2022;
  revert("Network: Unknown chain id");
}

function key(Network network) pure returns (TNetwork) {
  return TNetwork.wrap(LibString.packOne(name(network)));
}

function explorer(Network network) pure returns (string memory link) {
  if (network == Network.Goerli) return "https://goerli.etherscan.io/";
  if (network == Network.EthMainnet) return "https://etherscan.io/";
}

function name(Network network) pure returns (string memory) {
  if (network == Network.Goerli) return "Goerli";
  if (network == Network.RoninDevnet) return "RoninDevnet";
  if (network == Network.EthMainnet) return "EthMainnet";
  revert("Network: Unknown network name");
}

function deploymentDir(Network network) pure returns (string memory) {
  if (network == Network.Goerli) return "goerli/";
  if (network == Network.EthMainnet) return "ethereum/";
  if (network == Network.RoninDevnet) return "ronin-devnet/";
  revert("Network: Unknown network deployment directory");
}

function envLabel(Network network) pure returns (string memory) {
  if (network == Network.Goerli) return "TESTNET_PK";
  if (network == Network.RoninDevnet) return "DEVNET_PK";
  if (network == Network.EthMainnet) return "MAINNET_PK";
  revert("Network: Unknown private key env label");
}

function chainAlias(Network network) pure returns (string memory) {
  if (network == Network.Goerli) return "goerli";
  if (network == Network.EthMainnet) return "ethereum";
  if (network == Network.RoninDevnet) return "ronin-devnet";
  revert("Network: Unknown network alias");
}
