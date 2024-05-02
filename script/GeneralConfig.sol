// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 as console } from "forge-std/console2.sol";
import { TContract } from "foundry-deployment-kit/types/Types.sol";
import { BaseGeneralConfig } from "foundry-deployment-kit/BaseGeneralConfig.sol";
import { Network } from "./utils/Network.sol";
import { Contract } from "./utils/Contract.sol";

contract GeneralConfig is BaseGeneralConfig {
  constructor() BaseGeneralConfig("", "deployments/") { }

  function _setUpNetworks() internal virtual override {
    setNetworkInfo(
      Network.Goerli.chainId(),
      Network.Goerli.key(),
      Network.Goerli.chainAlias(),
      Network.Goerli.deploymentDir(),
      Network.Goerli.envLabel(),
      Network.Goerli.explorer()
    );
    setNetworkInfo(
      Network.EthMainnet.chainId(),
      Network.EthMainnet.key(),
      Network.EthMainnet.chainAlias(),
      Network.EthMainnet.deploymentDir(),
      Network.EthMainnet.envLabel(),
      Network.EthMainnet.explorer()
    );
    setNetworkInfo(
      Network.RoninDevnet.chainId(),
      Network.RoninDevnet.key(),
      Network.RoninDevnet.chainAlias(),
      Network.RoninDevnet.deploymentDir(),
      Network.RoninDevnet.envLabel(),
      Network.RoninDevnet.explorer()
    );
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

    // override artifact name with contract name
    _contractNameMap[Contract.RoninGatewayPauseEnforcer.key()] = "PauseEnforcer";
    _contractNameMap[Contract.HardForkRoninGovernanceAdmin.key()] = Contract.RoninGovernanceAdmin.name();
    _contractNameMap[Contract.TemporalRoninTrustedOrganization.key()] = Contract.RoninTrustedOrganization.name();

    if (block.chainid == 2021) {
      _contractNameMap[Contract.Profile.key()] = "Profile";
    } else if (block.chainid == 2020) {
      _contractNameMap[Contract.Profile.key()] = "Profile_Mainnet";
    }
  }

  function _mapContractName(Contract contractEnum) internal {
    _contractNameMap[contractEnum.key()] = contractEnum.name();
  }
}
