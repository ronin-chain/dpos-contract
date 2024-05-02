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
      _setRoninRandomBeaconParam(param.roninRandomBeacon);
    } else {
      revert("DPoSMigration: Other network unsupported");
    }

    rawArgs = abi.encode(param);
  }

  function _setRoninRandomBeaconParam(ISharedArgument.RoninRandomBeaconParam memory param) internal view {
    param.slashThreshold = vm.envOr("RANDOM_BEACON_SLASH_THRESHOLD", uint256(3));
    param.initialSeed = vm.envOr("INITIAL_SEED", uint256(1432));
    param.activatedAtPeriod = vm.envOr("RANDOM_BEACON_ACTIVATED_AT_PERIOD", uint256(0));
    param.validatorTypes = new IRandomBeacon.ValidatorType[](4);
    param.validatorTypes[0] = IRandomBeacon.ValidatorType.Governing;
    param.validatorTypes[1] = IRandomBeacon.ValidatorType.Standard;
    param.validatorTypes[2] = IRandomBeacon.ValidatorType.Rotating;
    param.validatorTypes[3] = IRandomBeacon.ValidatorType.All;
    param.thresholds = new uint256[](4);
    param.thresholds[0] = vm.envOr("GOVERNING_VALIDATOR_THRESHOLD", uint256(12));
    param.thresholds[1] = vm.envOr("STANDARD_VALIDATOR_THRESHOLD", uint256(5));
    param.thresholds[2] = vm.envOr("ROTATING_VALIDATOR_THRESHOLD", uint256(5));
    param.thresholds[3] = vm.envOr("ALL_VALIDATOR_THRESHOLD", uint256(22));
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
    param.minValidatorStakingAmount = vm.envOr("MIN_VALIDATOR_STAKING_AMOUNT", uint256(100 ether));
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

    // Slash random beacon
    param.slashRandomBeacon.randomBeaconSlashAmount = vm.envOr("SLASH_RANDOM_BEACON_AMOUNT", uint256(10 ether));

    // Credit score
    param.creditScore.gainCreditScore = vm.envOr("GAIN_CREDIT_SCORE", uint256(100));
    param.creditScore.maxCreditScore = vm.envOr("MAX_CREDIT_SCORE", uint256(2400));
    param.creditScore.bailOutCostMultiplier = vm.envOr("BAIL_OUT_COST_MULTIPLIER", uint256(2));
    param.creditScore.cutOffPercentageAfterBailout = vm.envOr("CUT_OFF_PERCENTAGE_AFTER_BAILOUT", uint256(50_00)); // 50%
  }

  function _setTrustedOrganizationParam(ISharedArgument.RoninTrustedOrganizationParam memory param) internal {
    param.trustedOrganizations = new IRoninTrustedOrganization.TrustedOrganization[](12);

    for (uint256 i; i < param.trustedOrganizations.length; i++) {
      param.trustedOrganizations[i].weight = vm.envOr("TRUSTED_ORGANIZATION_WEIGHT", uint256(100));
      param.trustedOrganizations[i].governor =
        vm.envOr("TRUSTED_ORGANIZATION_GOVERNOR", makeAddr(string.concat("governor-", vm.toString(i))));
      param.trustedOrganizations[i].consensusAddr = TConsensus.wrap(
        vm.envOr("TRUSTED_ORGANIZATION_CONSENSUS_ADDR", makeAddr(string.concat("consensus-", vm.toString(i))))
      );
    }

    param.numerator = vm.envOr("TRUSTED_ORGANIZATION_NUMERATOR", uint256(0));
    param.denominator = vm.envOr("TRUSTED_ORGANIZATION_DENOMINATOR", uint256(1));
  }

  function _setRoninValidatorSetParam(ISharedArgument.RoninValidatorSetParam memory param) internal view {
    param.maxValidatorNumber = vm.envOr("MAX_VALIDATOR_NUMBER", uint256(22));
    param.maxPrioritizedValidatorNumber = vm.envOr("MAX_PRIORITIZED_VALIDATOR_NUMBER", uint256(12));
    param.numberOfBlocksInEpoch = vm.envOr("NUMBER_OF_BLOCKS_IN_EPOCH", uint256(200));
    param.maxValidatorCandidate = vm.envOr("MAX_VALIDATOR_CANDIDATE", uint256(100));
    param.minEffectiveDaysOnwards = vm.envOr("MIN_EFFECTIVE_DAYS_ONWARDS", uint256(7));
    param.emergencyExitLockedAmount = vm.envOr("EMERGENCY_EXIT_LOCKED_AMOUNT", uint256(500));
    param.emergencyExpiryDuration = vm.envOr("EMERGENCY_EXPIRY_DURATION", uint256(14 days));
  }

  function _setGovernanceAdminParam(ISharedArgument.GovernanceAdminParam memory param) internal view {
    param.proposalExpiryDuration = vm.envOr("PROPOSAL_EXPIRY_DURATION", uint256(14 days));
  }
}
