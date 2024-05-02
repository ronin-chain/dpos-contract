// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IGeneralConfig } from "foundry-deployment-kit/interfaces/IGeneralConfig.sol";
import { IRoninTrustedOrganization } from "@ronin/contracts/interfaces/IRoninTrustedOrganization.sol";
import { IRandomBeacon } from "@ronin/contracts/interfaces/random-beacon/IRandomBeacon.sol";

interface ISharedArgument is IGeneralConfig {
  struct SlashBridgeOperatorParam {
    uint256 missingVotesRatioTier1;
    uint256 missingVotesRatioTier2;
    uint256 jailDurationForMissingVotesRatioTier2;
    uint256 skipBridgeOperatorSlashingThreshold;
  }

  struct SlashRandomBeaconParam {
    uint256 randomBeaconSlashAmount;
  }

  struct SlashBridgeVotingParam {
    uint256 bridgeVotingThreshold;
    uint256 bridgeVotingSlashAmount;
  }

  struct SlashDoubleSignParam {
    uint256 slashDoubleSignAmount;
    uint256 doubleSigningJailUntilBlock;
    uint256 doubleSigningOffsetLimitBlock;
  }

  struct SlashUnavailabilityParam {
    uint256 unavailabilityTier1Threshold;
    uint256 unavailabilityTier2Threshold;
    uint256 slashAmountForUnavailabilityTier2Threshold;
    uint256 jailDurationForUnavailabilityTier2Threshold;
  }

  struct CreditScoreParam {
    uint256 gainCreditScore;
    uint256 maxCreditScore;
    uint256 bailOutCostMultiplier;
    uint256 cutOffPercentageAfterBailout;
  }

  struct MaintenanceParam {
    uint256 minMaintenanceDurationInBlock;
    uint256 maxMaintenanceDurationInBlock;
    uint256 minOffsetToStartSchedule;
    uint256 maxOffsetToStartSchedule;
    uint256 maxSchedules;
    uint256 cooldownSecsToMaintain;
  }

  struct StakingParam {
    uint256 minValidatorStakingAmount;
    uint256 maxCommissionRate;
    uint256 cooldownSecsToUndelegate;
    uint256 waitingSecsToRevoke;
  }

  struct StakingVestingParam {
    uint256 topupAmount;
    uint256 blockProducerBonusPerBlock;
    uint256 bridgeOperatorBonusPerBlock;
    uint256 fastFinalityRewardPercent;
  }

  struct RoninValidatorSetParam {
    uint256 maxValidatorNumber;
    uint256 maxValidatorCandidate;
    uint256 maxPrioritizedValidatorNumber;
    uint256 numberOfBlocksInEpoch;
    uint256 minEffectiveDaysOnwards;
    uint256 emergencyExitLockedAmount;
    uint256 emergencyExpiryDuration;
  }

  struct GovernanceAdminParam {
    uint256 proposalExpiryDuration;
  }

  struct RoninTrustedOrganizationParam {
    IRoninTrustedOrganization.TrustedOrganization[] trustedOrganizations;
    uint256 numerator;
    uint256 denominator;
  }

  struct ProfileParam {
    uint256 cooldown;
  }

  struct RoninRandomBeaconParam {
    uint256 slashThreshold;
    uint256 initialSeed;
    uint256 activatedAtPeriod;
    IRandomBeacon.ValidatorType[] validatorTypes;
    uint256[] thresholds;
  }

  struct SlashIndicatorParam {
    CreditScoreParam creditScore;
    SlashDoubleSignParam slashDoubleSign;
    SlashUnavailabilityParam slashUnavailability;
    SlashRandomBeaconParam slashRandomBeacon;
    SlashBridgeVotingParam __deprecatedSlashBridgeVoting;
    SlashBridgeOperatorParam __deprecatedSlashBridgeOperator;
  }

  struct SharedParameter {
    address initialOwner;
    ProfileParam profile;
    StakingParam staking;
    MaintenanceParam maintenance;
    StakingVestingParam stakingVesting;
    SlashIndicatorParam slashIndicator;
    GovernanceAdminParam governanceAdmin;
    RoninValidatorSetParam roninValidatorSet;
    RoninTrustedOrganizationParam trustedOrganization;
    RoninRandomBeaconParam roninRandomBeacon;
  }

  function sharedArguments() external view returns (SharedParameter memory param);
}
