// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TContract } from "foundry-deployment-kit/types/Types.sol";
import { LibString } from "lib/foundry-deployment-kit/lib/solady/src/utils/LibString.sol";

enum Contract {
  Profile,
  Staking,
  Maintenance,
  BridgeSlash,
  BridgeReward,
  RoninGatewayV3,
  SlashIndicator,
  NotifiedMigrator,
  MockPrecompile,
  BridgeTracking,
  StakingVesting,
  RoninValidatorSet,
  MainchainGatewayV3,
  RoninBridgeManager,
  RoninGovernanceAdmin,
  FastFinalityTracking,
  MainchainBridgeManager,
  MainchainGovernanceAdmin,
  RoninGatewayPauseEnforcer,
  RoninTrustedOrganization,
  HardForkRoninGovernanceAdmin,
  TemporalRoninTrustedOrganization,
  RoninValidatorSetTimedMigrator
}

using { key, name } for Contract global;

function key(Contract contractEnum) pure returns (TContract) {
  return TContract.wrap(LibString.packOne(name(contractEnum)));
}

function name(Contract contractEnum) pure returns (string memory) {
  if (contractEnum == Contract.Profile) return "Profile";
  if (contractEnum == Contract.Staking) return "Staking";
  if (contractEnum == Contract.Maintenance) return "Maintenance";
  if (contractEnum == Contract.BridgeSlash) return "BridgeSlash";
  if (contractEnum == Contract.BridgeReward) return "BridgeReward";
  if (contractEnum == Contract.RoninGatewayV3) return "RoninGatewayV3";
  if (contractEnum == Contract.SlashIndicator) return "SlashIndicator";
  if (contractEnum == Contract.NotifiedMigrator) return "NotifiedMigrator";
  if (contractEnum == Contract.MockPrecompile) return "MockPrecompile";
  if (contractEnum == Contract.BridgeTracking) return "BridgeTracking";
  if (contractEnum == Contract.StakingVesting) return "StakingVesting";
  if (contractEnum == Contract.RoninValidatorSet) return "RoninValidatorSet";
  if (contractEnum == Contract.MainchainGatewayV3) return "MainchainGatewayV3";
  if (contractEnum == Contract.RoninBridgeManager) return "RoninBridgeManager";
  if (contractEnum == Contract.RoninGovernanceAdmin) return "RoninGovernanceAdmin";
  if (contractEnum == Contract.FastFinalityTracking) return "FastFinalityTracking";
  if (contractEnum == Contract.MainchainBridgeManager) return "MainchainBridgeManager";
  if (contractEnum == Contract.MainchainGovernanceAdmin) return "MainchainGovernanceAdmin";
  if (contractEnum == Contract.RoninTrustedOrganization) return "RoninTrustedOrganization";
  if (contractEnum == Contract.RoninGatewayPauseEnforcer) return "RoninGatewayPauseEnforcer";
  if (contractEnum == Contract.HardForkRoninGovernanceAdmin) return "HardForkGovernanceAdmin";
  if (contractEnum == Contract.TemporalRoninTrustedOrganization) return "TemporalTrustedOrganization";
  if (contractEnum == Contract.RoninValidatorSetTimedMigrator) return "RoninValidatorSetTimedMigrator";
  revert("Contract: Unknown contract");
}
