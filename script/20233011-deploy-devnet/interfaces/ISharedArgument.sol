// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IGeneralConfig } from "@fdk/interfaces/IGeneralConfig.sol";
import { IRoninTrustedOrganization } from "@ronin/contracts/interfaces/IRoninTrustedOrganization.sol";

interface ISharedArgument is IGeneralConfig {
  struct BridgeOperatorSlashing {
    uint256 missingVotesRatioTier1;
    uint256 missingVotesRatioTier2;
    uint256 jailDurationForMissingVotesRatioTier2;
    uint256 skipBridgeOperatorSlashingThreshold;
  }

  struct BridgeVotingSlashing {
    uint256 bridgeVotingThreshold;
    uint256 bridgeVotingSlashAmount;
  }

  struct DoubleSignSlashing {
    uint256 slashDoubleSignAmount;
    uint256 doubleSigningJailUntilBlock;
    uint256 doubleSigningOffsetLimitBlock;
  }

  struct UnavailabilitySlashing {
    uint256 unavailabilityTier1Threshold;
    uint256 unavailabilityTier2Threshold;
    uint256 slashAmountForUnavailabilityTier2Threshold;
    uint256 jailDurationForUnavailabilityTier2Threshold;
  }

  struct CreditScore {
    uint256 gainCreditScore;
    uint256 maxCreditScore;
    uint256 bailOutCostMultiplier;
    uint256 cutOffPercentageAfterBailout;
  }

  struct SharedParameter {
    address initialOwner;
    // maintenance
    uint256 minMaintenanceDurationInBlock;
    uint256 maxMaintenanceDurationInBlock;
    uint256 minOffsetToStartSchedule;
    uint256 maxOffsetToStartSchedule;
    uint256 maxSchedules;
    uint256 cooldownSecsToMaintain;
    // staking
    uint256 minValidatorStakingAmount;
    uint256 maxCommissionRate;
    uint256 cooldownSecsToUndelegate;
    uint256 waitingSecsToRevoke;
    // staking vesting
    uint256 topupAmount;
    uint256 blockProducerBonusPerBlock;
    uint256 bridgeOperatorBonusPerBlock;
    uint256 fastFinalityRewardPercent;
    // slash indicator
    CreditScore creditScore;
    DoubleSignSlashing doubleSignSlashing;
    BridgeVotingSlashing bridgeVotingSlashing;
    UnavailabilitySlashing unavailabilitySlashing;
    BridgeOperatorSlashing bridgeOperatorSlashing;
    // ronin validator set
    uint256 maxValidatorNumber;
    uint256 maxValidatorCandidate;
    uint256 maxPrioritizedValidatorNumber;
    uint256 numberOfBlocksInEpoch;
    uint256 minEffectiveDaysOnwards;
    uint256 emergencyExitLockedAmount;
    uint256 emergencyExpiryDuration;
    // ronin trusted organization
    IRoninTrustedOrganization.TrustedOrganization[] trustedOrganizations;
    uint256 numerator;
    uint256 denominator;
    // governance admin
    uint256 proposalExpiryDuration;
  }

  function sharedArguments() external view returns (SharedParameter memory param);
}
