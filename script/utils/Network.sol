// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { INetworkConfig } from "@fdk/interfaces/configs/INetworkConfig.sol";
import { LibString, TNetwork } from "@fdk/types/TNetwork.sol";

enum Network {
  Goerli,
  EthMainnet,
  RoninDevnet,
  RoninMainnetShadow,
  RoninTestnetShadow
}

using { key, chainId, chainAlias, explorer, data } for Network global;

function data(
  Network network
) pure returns (INetworkConfig.NetworkData memory) {
  return INetworkConfig.NetworkData({
    network: key(network),
    chainAlias: chainAlias(network),
    blockTime: blockTime(network),
    explorer: explorer(network),
    chainId: chainId(network)
  });
}

function blockTime(
  Network network
) pure returns (uint256) {
  if (network == Network.Goerli) return 15;
  if (network == Network.EthMainnet) return 15;
  if (network == Network.RoninDevnet) return 3;
  if (network == Network.RoninMainnetShadow) return 3;
  if (network == Network.RoninTestnetShadow) return 3;
  revert("Network: Unknown block time");
}

function chainId(
  Network network
) pure returns (uint256) {
  if (network == Network.Goerli) return 5;
  if (network == Network.EthMainnet) return 1;
  if (network == Network.RoninDevnet) return 2021;
  if (network == Network.RoninMainnetShadow) return 6060;
  if (network == Network.RoninTestnetShadow) return 6063;
  revert("Network: Unknown chain id");
}

function key(
  Network network
) pure returns (TNetwork) {
  return TNetwork.wrap(LibString.packOne(chainAlias(network)));
}

function explorer(
  Network network
) pure returns (string memory link) {
  if (network == Network.Goerli) return "https://goerli.etherscan.io/";
  if (network == Network.EthMainnet) return "https://etherscan.io/";
  if (network == Network.RoninMainnetShadow) return "https://app.roninchain.com/";
  if (network == Network.RoninDevnet) return "https://ronindev-explorer.sandbox.roninchain.com/";
  if (network == Network.RoninTestnetShadow) return "https://shadow.sandbox.roninchain.com/";
}

function chainAlias(
  Network network
) pure returns (string memory) {
  if (network == Network.Goerli) return "goerli";
  if (network == Network.EthMainnet) return "ethereum";
  if (network == Network.RoninDevnet) return "ronin-devnet";
  if (network == Network.RoninMainnetShadow) return "ronin-mainnet-shadow";
  if (network == Network.RoninTestnetShadow) return "ronin-testnet-shadow";
  revert("Network: Unknown network alias");
}
