// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { ISlashDoubleSign } from "./ISlashDoubleSign.sol";
import { ISlashUnavailability } from "./ISlashUnavailability.sol";
import { ICreditScore } from "./ICreditScore.sol";
import { ISlashRandomBeacon } from "./ISlashRandomBeacon.sol";

interface ISlashIndicator is ISlashDoubleSign, ISlashUnavailability, ICreditScore, ISlashRandomBeacon {
  function initialize(
    address __validatorContract,
    address __maintenanceContract,
    address __roninTrustedOrganizationContract,
    address __roninGovernanceAdminContract,
    uint256[4] calldata, /* _bridgeOperatorSlashingConfigs */
    uint256[2] calldata, /* _bridgeVotingSlashingConfigs */
    // _doubleSignSlashingConfigs[0]: _slashDoubleSignAmount
    // _doubleSignSlashingConfigs[1]: _doubleSigningJailUntilBlock
    // _doubleSignSlashingConfigs[2]: _doubleSigningOffsetLimitBlock
    uint256[3] calldata _doubleSignSlashingConfigs,
    // _unavailabilitySlashingConfigs[0]: _unavailabilityTier1Threshold
    // _unavailabilitySlashingConfigs[1]: _unavailabilityTier2Threshold
    // _unavailabilitySlashingConfigs[2]: _slashAmountForUnavailabilityTier2Threshold
    // _unavailabilitySlashingConfigs[3]: _jailDurationForUnavailabilityTier2Threshold
    uint256[4] calldata _unavailabilitySlashingConfigs,
    // _creditScoreConfigs[0]: _gainCreditScore
    // _creditScoreConfigs[1]: _maxCreditScore
    // _creditScoreConfigs[2]: _bailOutCostMultiplier
    // _creditScoreConfigs[3]: _cutOffPercentageAfterBailout
    uint256[4] calldata _creditScoreConfigs
  ) external;

  function initializeV2(
    address roninGovernanceAdminContract
  ) external;

  function initializeV3(
    address profileContract
  ) external;

  function initializeV4(
    address randomBeaconContract,
    uint256 randomBeaconSlashAmount,
    uint256 activatedAtPeriod
  ) external;
}
