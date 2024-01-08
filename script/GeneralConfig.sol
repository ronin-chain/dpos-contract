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
    _mapContractname(Contract.Profile);
    _mapContractname(Contract.Profile_Testnet);
    _mapContractname(Contract.Staking);
    _mapContractname(Contract.Maintenance);
    _mapContractname(Contract.BridgeSlash);
    _mapContractname(Contract.BridgeReward);
    _mapContractname(Contract.RoninGatewayV3);
    _mapContractname(Contract.SlashIndicator);
    _mapContractname(Contract.NotifiedMigrator);
    _mapContractname(Contract.MockPrecompile);
    _mapContractname(Contract.BridgeTracking);
    _mapContractname(Contract.StakingVesting);
    _mapContractname(Contract.RoninValidatorSet);
    _mapContractname(Contract.MainchainGatewayV3);
    _mapContractname(Contract.RoninBridgeManager);
    _mapContractname(Contract.RoninGovernanceAdmin);
    _mapContractname(Contract.FastFinalityTracking);
    _mapContractname(Contract.MainchainBridgeManager);
    _mapContractname(Contract.MainchainGovernanceAdmin);
    _mapContractname(Contract.RoninTrustedOrganization);
    _mapContractname(Contract.RoninValidatorSetTimedMigrator);

    // override artifact name with contract name
    _contractNameMap[Contract.RoninGatewayPauseEnforcer.key()] = "PauseEnforcer";
    _contractNameMap[Contract.HardForkRoninGovernanceAdmin.key()] = Contract.RoninGovernanceAdmin.name();
    _contractNameMap[Contract.TemporalRoninTrustedOrganization.key()] = Contract.RoninTrustedOrganization.name();
  }

  function _mapContractname(Contract contractEnum) internal {
    _contractNameMap[contractEnum.key()] = contractEnum.name();
  }
}
