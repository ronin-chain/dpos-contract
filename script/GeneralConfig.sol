// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { BaseGeneralConfig } from "@fdk/BaseGeneralConfig.sol";
import { Network } from "./utils/Network.sol";
import { Contract } from "./utils/Contract.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { TNetwork } from "@fdk/types/TNetwork.sol";

contract GeneralConfig is BaseGeneralConfig {
  constructor() BaseGeneralConfig("", "deployments/") { }

  function _setUpNetworks() internal virtual override {
    setNetworkInfo(Network.Goerli.data());
    setNetworkInfo(Network.EthMainnet.data());
    setNetworkInfo(Network.RoninDevnet.data());
    setNetworkInfo(Network.ShadowForkMainnet.data());
  }

  function _setUpContracts() internal virtual override {
    _mapContractName(Contract.Profile);
    _mapContractName(Contract.Staking);
    _mapContractName(Contract.Maintenance);
    _mapContractName(Contract.BridgeSlash);
    _mapContractName(Contract.BridgeReward);
    _mapContractName(Contract.RoninGatewayV3);
    _mapContractName(Contract.SlashIndicator);
    _mapContractName(Contract.NotifiedMigrator);
    _mapContractName(Contract.MockPrecompile);
    _mapContractName(Contract.BridgeTracking);
    _mapContractName(Contract.StakingVesting);
    _mapContractName(Contract.RoninValidatorSet);
    _mapContractName(Contract.MainchainGatewayV3);
    _mapContractName(Contract.RoninBridgeManager);
    _mapContractName(Contract.RoninGovernanceAdmin);
    _mapContractName(Contract.FastFinalityTracking);
    _mapContractName(Contract.MainchainBridgeManager);
    _mapContractName(Contract.MainchainGovernanceAdmin);
    _mapContractName(Contract.RoninTrustedOrganization);
    _mapContractName(Contract.RoninValidatorSetTimedMigrator);
    _mapContractName(Contract.RoninRandomBeacon);
    _mapContractName(Contract.PostChecker);
    _mapContractName(Contract.RoninValidatorSetREP10Migrator);

    setContractAbsolutePathMap(Contract.PostChecker.key(), "out/PostChecker.sol/PostChecker.json");

    // override artifact name with contract name
    _contractNameMap[Contract.Profile.key()] = "Profile";
    _contractNameMap[Contract.RoninRandomBeacon.key()] = "RoninRandomBeacon_Devnet";
    _contractNameMap[Contract.RoninGatewayPauseEnforcer.key()] = "PauseEnforcer";
    _contractNameMap[Contract.HardForkRoninGovernanceAdmin.key()] = Contract.RoninGovernanceAdmin.name();
    _contractNameMap[Contract.TemporalRoninTrustedOrganization.key()] = Contract.RoninTrustedOrganization.name();

    TNetwork currNetwork = getCurrentNetwork();
    if (currNetwork == DefaultNetwork.RoninTestnet.key()) {
      _contractNameMap[Contract.Profile.key()] = "Profile";
      _contractNameMap[Contract.RoninRandomBeacon.key()] = "RoninRandomBeacon_Testnet";
    } else if (currNetwork == DefaultNetwork.RoninMainnet.key()) {
      _contractNameMap[Contract.Profile.key()] = "Profile_Mainnet";
      _contractNameMap[Contract.RoninRandomBeacon.key()] = "RoninRandomBeacon_Mainnet";
    }
  }

  function _mapContractName(Contract contractEnum) internal {
    _contractNameMap[contractEnum.key()] = contractEnum.name();
  }
}
