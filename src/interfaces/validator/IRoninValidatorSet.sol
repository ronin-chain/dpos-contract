// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { ICandidateManager } from "./ICandidateManager.sol";
import { ICandidateManagerCallback } from "./ICandidateManagerCallback.sol";

import { ICoinbaseExecution } from "./ICoinbaseExecution.sol";

import { IEmergencyExit } from "./IEmergencyExit.sol";
import { ISlashingExecution } from "./ISlashingExecution.sol";
import { ICommonInfo } from "./info-fragments/ICommonInfo.sol";

interface IRoninValidatorSet is
  ICandidateManagerCallback,
  ICandidateManager,
  ICommonInfo,
  ISlashingExecution,
  ICoinbaseExecution,
  IEmergencyExit
{
  /**
   * @dev Initializes the contract storage.
   */
  function initialize(
    address __slashIndicatorContract,
    address __stakingContract,
    address __stakingVestingContract,
    address __maintenanceContract,
    address __roninTrustedOrganizationContract,
    address, /* __bridgeTrackingContract */
    uint256, /* __maxValidatorNumber */
    uint256 __maxValidatorCandidate,
    uint256, /* __maxPrioritizedValidatorNumber */
    uint256 __minEffectiveDaysOnwards,
    uint256 __numberOfBlocksInEpoch,
    // __emergencyExitConfigs[0]: emergencyExitLockedAmount
    // __emergencyExitConfigs[1]: emergencyExpiryDuration
    uint256[2] calldata __emergencyExitConfigs
  ) external;

  function initializeV2() external;
  function initializeV3(
    address fastFinalityTrackingContract
  ) external;
  function initializeV4(
    address profileContract
  ) external;
  function initializeV5(
    address zkFeePlazaContract
  ) external;
}
