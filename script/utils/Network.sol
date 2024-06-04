// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibString, TNetwork } from "@fdk/types/Types.sol";
import { INetworkConfig } from "@fdk/interfaces/configs/INetworkConfig.sol";

enum Network {
  Goerli,
  EthMainnet,
  RoninDevnet
}

using { key, name, chainId, chainAlias, envLabel, deploymentDir, explorer, data } for Network global;

function data(Network network) pure returns (INetworkConfig.NetworkData memory) {
  return INetworkConfig.NetworkData({
    network: key(network),
    chainId: chainId(network),
    chainAlias: chainAlias(network),
    blockTime: blockTime(network),
    deploymentDir: deploymentDir(network),
    privateKeyEnvLabel: envLabel(network),
    explorer: explorer(network)
  });
}

function blockTime(Network network) pure returns (uint256) {
  if (network == Network.Goerli) return 15;
  if (network == Network.EthMainnet) return 15;
  if (network == Network.RoninDevnet) return 3;
  revert("Network: Unknown block time");
}

function chainId(Network network) pure returns (uint256) {
  if (network == Network.Goerli) return 5;
  if (network == Network.EthMainnet) return 1;
  if (network == Network.RoninDevnet) return 2021;
  revert("Network: Unknown chain id");
}

function key(Network network) pure returns (TNetwork) {
  return TNetwork.wrap(LibString.packOne(chainAlias(network)));
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
