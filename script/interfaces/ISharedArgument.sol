// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IGeneralConfig } from "@fdk/interfaces/IGeneralConfig.sol";
import { IRoninTrustedOrganization } from "src/interfaces/IRoninTrustedOrganization.sol";
import { IRandomBeacon } from "src/interfaces/random-beacon/IRandomBeacon.sol";

interface ISharedArgument is IGeneralConfig {
  struct SlashBridgeOperatorParam {
    uint256 missingVotesRatioTier1;
    uint256 missingVotesRatioTier2;
    uint256 jailDurationForMissingVotesRatioTier2;
    uint256 skipBridgeOperatorSlashingThreshold;
  }

  struct SlashRandomBeaconParam {
    uint256 activatedAtPeriod;
    uint256 randomBeaconSlashAmount;
  }

  struct SlashBridgeVotingParam {
    uint256 bridgeVotingThreshold;
    uint256 bridgeVotingSlashAmount;
  }

  struct SlashDoubleSignParam {
    uint256 doubleSigningJailUntilBlock;
    uint256 doubleSigningOffsetLimitBlock;
    uint256 slashDoubleSignAmount;
  }

  struct SlashUnavailabilityParam {
    uint256 jailDurationForUnavailabilityTier2Threshold;
    uint256 slashAmountForUnavailabilityTier2Threshold;
    uint256 unavailabilityTier1Threshold;
    uint256 unavailabilityTier2Threshold;
  }

  struct CreditScoreParam {
    uint256 bailOutCostMultiplier;
    uint256 cutOffPercentageAfterBailout;
    uint256 gainCreditScore;
    uint256 maxCreditScore;
  }

  struct MaintenanceParam {
    uint256 cooldownSecsToMaintain;
    uint256 maxMaintenanceDurationInBlock;
    uint256 maxOffsetToStartSchedule;
    uint256 maxSchedules;
    uint256 minMaintenanceDurationInBlock;
    uint256 minOffsetToStartSchedule;
  }

  struct StakingParam {
    uint256 cooldownSecsToUndelegate;
    uint256 maxCommissionRate;
    uint256 minValidatorStakingAmount;
    uint256 waitingSecsToRevoke;
  }

  struct StakingVestingParam {
    uint256 activatedAtPeriod; // REP-10 activation period
    uint256 blockProducerBonusPerBlock;
    uint256 bridgeOperatorBonusPerBlock;
    uint256 fastFinalityRewardPercent;
    uint256 fastFinalityRewardPercentREP10; // REP-10 fast finality reward percentage
    uint256 topupAmount;
  }

  struct RoninValidatorSetParam {
    uint256 emergencyExitLockedAmount;
    uint256 emergencyExpiryDuration;
    uint256 maxPrioritizedValidatorNumber;
    uint256 maxValidatorCandidate;
    uint256 maxValidatorNumber;
    uint256 minEffectiveDaysOnwards;
    uint256 numberOfBlocksInEpoch;
  }

  struct RoninGovernanceAdminParam {
    uint256 proposalExpiryDuration;
  }

  struct RoninTrustedOrganizationParam {
    uint256 denominator;
    uint256 numerator;
    TrustedOrganization[] trustedOrganizations;
  }

  struct TrustedOrganization {
    // Address to voting bridge operators
    address __deprecatedBridgeVoter;
    // The block that the organization was added
    uint256 addedBlock;
    // Address of the validator that produces block, e.g. block.coinbase. This is so-called validator address.
    address consensusAddr;
    // Address to voting proposal
    address governor;
    // Its Weight
    uint256 weight;
  }

  struct ProfileParam {
    uint256 cooldown;
  }

  struct RoninRandomBeaconParam {
    uint256 activatedAtPeriod;
    uint256 slashThreshold;
    uint256[] thresholds;
    IRandomBeacon.ValidatorType[] validatorTypes;
  }

  struct SlashIndicatorParam {
    SlashBridgeOperatorParam __deprecatedSlashBridgeOperator;
    SlashBridgeVotingParam __deprecatedSlashBridgeVoting;
    CreditScoreParam creditScore;
    SlashDoubleSignParam slashDoubleSign;
    SlashRandomBeaconParam slashRandomBeacon;
    SlashUnavailabilityParam slashUnavailability;
  }

  struct RoninValidatorSetREP10MigratorParam {
    uint256 activatedAtPeriod;
  }

  struct RoninBaseFeeTreasuryParam {
    uint8 denom;
    uint8 num;
  }

  struct SharedParameter {
    address initialOwner;
    MaintenanceParam maintenance;
    ProfileParam profile;
    RoninBaseFeeTreasuryParam roninBaseFeeTreasury;
    RoninGovernanceAdminParam roninGovernanceAdmin;
    RoninRandomBeaconParam roninRandomBeacon;
    RoninTrustedOrganizationParam roninTrustedOrganization;
    RoninValidatorSetParam roninValidatorSet;
    RoninValidatorSetREP10MigratorParam roninValidatorSetREP10Migrator;
    SlashIndicatorParam slashIndicator;
    StakingParam staking;
    StakingVestingParam stakingVesting;
  }

  function sharedArguments() external view returns (SharedParameter memory param);
}
