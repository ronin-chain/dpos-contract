// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { DefaultNetwork } from "foundry-deployment-kit/utils/DefaultNetwork.sol";
import { Network } from "script/utils/Network.sol";
import { Contract } from "script/utils/Contract.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";
import "./interfaces/ISharedArgument.sol";
import { TConsensus } from "@ronin/contracts/udvts/Types.sol";

contract DPoSMigration is RoninMigration {
  ISharedArgument internal constant cfg = ISharedArgument(address(CONFIG));

  function _getProxyAdminFromCurrentNetwork() internal view virtual override returns (address proxyAdmin) {
    proxyAdmin = super._getProxyAdminFromCurrentNetwork();
    if (network() == DefaultNetwork.Local.key()) {
      address deployedProxyAdmin;
      try cfg.getAddressFromCurrentNetwork(Contract.RoninGovernanceAdmin.key()) returns (address payable res) {
        deployedProxyAdmin = res;
      } catch { }

      proxyAdmin = deployedProxyAdmin == address(0x0) ? cfg.sharedArguments().initialOwner : deployedProxyAdmin;
    }
  }

  function _sharedArguments() internal virtual override returns (bytes memory rawArgs) {
    ISharedArgument.SharedParameter memory param;

    if (network() == DefaultNetwork.Local.key()) {
      param.initialOwner = makeAddr("initial-owner");
      _setStakingParam(param.staking);
      _setMaintenanceParam(param.maintenance);
      _setStakingVestingParam(param.stakingVesting);
      _setSlashIndicatorParam(param.slashIndicator);
      _setGovernanceAdminParam(param.governanceAdmin);
      _setRoninValidatorSetParam(param.roninValidatorSet);
      _setTrustedOrganizationParam(param.trustedOrganization);
    } else {
      revert("DPoSMigration: Other network unsupported");
    }

    rawArgs = abi.encode(param);
  }

  function _setMaintenanceParam(ISharedArgument.MaintenanceParam memory param) internal view {
    param.maxSchedules = vm.envOr("MAX_SCHEDULES", uint256(3));
    param.minOffsetToStartSchedule = vm.envOr("MIN_OFFSET_TO_START_SCHEDULE", uint256(200));
    param.cooldownSecsToMaintain = vm.envOr("COOLDOWN_SECS_TO_MAINTAIN", uint256(3 days));
    param.maxOffsetToStartSchedule = vm.envOr("MAX_OFFSET_TO_START_SCHEDULE", uint256(200 * 7));
    param.minMaintenanceDurationInBlock = vm.envOr("MIN_MAINTENANCE_DURATION_IN_BLOCK", uint256(100));
    param.maxMaintenanceDurationInBlock = vm.envOr("MAX_MAINTENANCE_DURATION_IN_BLOCK", uint256(1000));
  }

  function _setStakingParam(ISharedArgument.StakingParam memory param) internal view {
    param.maxCommissionRate = vm.envOr("MAX_COMMISSION_RATE", uint256(100_00));
    param.waitingSecsToRevoke = vm.envOr("WAITING_SECS_TO_REVOKE", uint256(7 days));
    param.minValidatorStakingAmount = vm.envOr("MIN_VALIDATOR_STAKING_AMOUNT", uint256(100));
    param.cooldownSecsToUndelegate = vm.envOr("COOLDOWN_SECS_TO_UNDELEGATE", uint256(3 days));
  }

  function _setStakingVestingParam(ISharedArgument.StakingVestingParam memory param) internal view {
    param.topupAmount = vm.envOr("TOPUP_AMOUNT", uint256(100_000_000_000));
    param.fastFinalityRewardPercent = vm.envOr("FAST_FINALITY_REWARD_PERCENT", uint256(1_00)); // 1%
    param.blockProducerBonusPerBlock = vm.envOr("BLOCK_PRODUCER_BONUS_PER_BLOCK", uint256(1_000));
    param.bridgeOperatorBonusPerBlock = vm.envOr("BRIDGE_OPERATOR_BONUS_PER_BLOCK", uint256(1_100));
  }

  function _setSlashIndicatorParam(ISharedArgument.SlashIndicatorParam memory param) internal view {
    // Deprecated slash bridge operator
    param.__deprecatedSlashBridgeOperator.missingVotesRatioTier1 = vm.envOr("MISSING_VOTES_RATIO_TIER1", uint256(10_00)); // 10%
    param.__deprecatedSlashBridgeOperator.missingVotesRatioTier2 = vm.envOr("MISSING_VOTES_RATIO_TIER2", uint256(20_00)); // 20%
    param.__deprecatedSlashBridgeOperator.skipBridgeOperatorSlashingThreshold =
      vm.envOr("SKIP_BRIDGE_OPERATOR_SLASHING_THRESHOLD", uint256(10));
    param.__deprecatedSlashBridgeOperator.jailDurationForMissingVotesRatioTier2 =
      vm.envOr("JAIL_DURATION_FOR_MISSING_VOTES_RATIO_TIER2", uint256(28800 * 2));

    // Deprecated slash bridge voting
    param.__deprecatedSlashBridgeVoting.bridgeVotingThreshold = vm.envOr("BRIDGE_VOTING_THRESHOLD", uint256(28800 * 3));
    param.__deprecatedSlashBridgeVoting.bridgeVotingSlashAmount =
      vm.envOr("BRIDGE_VOTING_SLASH_AMOUNT", uint256(10_000 ether));

    // Slash double sign
    param.slashDoubleSign.slashDoubleSignAmount = vm.envOr("SLASH_DOUBLE_SIGN_AMOUNT", uint256(10 ether));
    param.slashDoubleSign.doubleSigningOffsetLimitBlock = vm.envOr("DOUBLE_SIGNING_OFFSET_LIMIT_BLOCK", uint256(28800));
    param.slashDoubleSign.doubleSigningJailUntilBlock =
      vm.envOr("DOUBLE_SIGNING_JAIL_UNTIL_BLOCK", uint256(type(uint256).max));

    // Slash unavailability
    param.slashUnavailability.unavailabilityTier1Threshold = vm.envOr("UNAVAILABILITY_TIER1_THRESHOLD", uint256(5));
    param.slashUnavailability.unavailabilityTier2Threshold = vm.envOr("UNAVAILABILITY_TIER2_THRESHOLD", uint256(10));
    param.slashUnavailability.slashAmountForUnavailabilityTier2Threshold =
      vm.envOr("SLASH_AMOUNT_FOR_UNAVAILABILITY_TIER2_THRESHOLD", uint256(1 ether));
    param.slashUnavailability.jailDurationForUnavailabilityTier2Threshold =
      vm.envOr("JAIL_DURATION_FOR_UNAVAILABILITY_TIER2_THRESHOLD", uint256(28800 * 2));

    // Credit score
    param.creditScore.gainCreditScore = vm.envOr("GAIN_CREDIT_SCORE", uint256(50));
    param.creditScore.maxCreditScore = vm.envOr("MAX_CREDIT_SCORE", uint256(600));
    param.creditScore.bailOutCostMultiplier = vm.envOr("BAIL_OUT_COST_MULTIPLIER", uint256(5));
    param.creditScore.cutOffPercentageAfterBailout = vm.envOr("CUT_OFF_PERCENTAGE_AFTER_BAILOUT", uint256(50_00)); // 50%
  }

  function _setTrustedOrganizationParam(ISharedArgument.RoninTrustedOrganizationParam memory param) internal view {
    param.trustedOrganizations = new IRoninTrustedOrganization.TrustedOrganization[](3);
    param.trustedOrganizations[0].weight = vm.envOr("TRUSTED_ORGANIZATION_0_WEIGHT", uint256(100));
    param.trustedOrganizations[1].weight = vm.envOr("TRUSTED_ORGANIZATION_1_WEIGHT", uint256(100));
    param.trustedOrganizations[2].weight = vm.envOr("TRUSTED_ORGANIZATION_2_WEIGHT", uint256(100));

    param.trustedOrganizations[0].governor =
      vm.envOr("TRUSTED_ORGANIZATION_0_GOVERNOR", address(0x529502C69356E9f48C8D5427B030020941F9ef42));
    param.trustedOrganizations[0].consensusAddr = TConsensus.wrap(
      vm.envOr("TRUSTED_ORGANIZATION_0_CONSENSUS_ADDR", address(0x6D863059CF618cC03d314cfbC41707105DD3BB3d))
    );

    param.trustedOrganizations[1].governor =
      vm.envOr("TRUSTED_ORGANIZATION_1_GOVERNOR", address(0x85C5dBfadcBc36AeE39DD32365183c5E38A67E37));
    param.trustedOrganizations[1].consensusAddr = TConsensus.wrap(
      vm.envOr("TRUSTED_ORGANIZATION_1_CONSENSUS_ADDR", address(0x412cA41498e0522f054ebBA32fCaf59C9e55F099))
    );

    param.trustedOrganizations[2].governor =
      vm.envOr("TRUSTED_ORGANIZATION_2_GOVERNOR", address(0x947AB99ad90302b5ec1840c9b5CF4205554C72af));
    param.trustedOrganizations[2].consensusAddr = TConsensus.wrap(
      vm.envOr("TRUSTED_ORGANIZATION_2_CONSENSUS_ADDR", address(0x7CcE47da0E161BE6fA1c7D09A9d12986b03621A3))
    );

    param.numerator = vm.envOr("TRUSTED_ORGANIZATION_NUMERATOR", uint256(0));
    param.denominator = vm.envOr("TRUSTED_ORGANIZATION_DENOMINATOR", uint256(1));
  }

  function _setRoninValidatorSetParam(ISharedArgument.RoninValidatorSetParam memory param) internal view {
    param.maxValidatorNumber = vm.envOr("MAX_VALIDATOR_NUMBER", uint256(4));
    param.maxPrioritizedValidatorNumber = vm.envOr("MAX_PRIORITIZED_VALIDATOR_NUMBER", uint256(0));
    param.numberOfBlocksInEpoch = vm.envOr("NUMBER_OF_BLOCKS_IN_EPOCH", uint256(200));
    param.maxValidatorCandidate = vm.envOr("MAX_VALIDATOR_CANDIDATE", uint256(10));
    param.minEffectiveDaysOnwards = vm.envOr("MIN_EFFECTIVE_DAYS_ONWARDS", uint256(7));
    param.emergencyExitLockedAmount = vm.envOr("EMERGENCY_EXIT_LOCKED_AMOUNT", uint256(500));
    param.emergencyExpiryDuration = vm.envOr("EMERGENCY_EXPIRY_DURATION", uint256(14 days));
  }

  function _setGovernanceAdminParam(ISharedArgument.GovernanceAdminParam memory param) internal view {
    param.proposalExpiryDuration = vm.envOr("PROPOSAL_EXPIRY_DURATION", uint256(14 days));
  }
}
