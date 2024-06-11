// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { RandomRequest } from "../../libraries/LibSLA.sol";
import { LibSortValidatorsByBeacon } from "../../libraries/LibSortValidatorsByBeacon.sol";
import { VRF } from "@chainlink/contracts/src/v0.8/VRF.sol";
import { TConsensus } from "../../udvts/Types.sol";

interface IRandomBeacon {
  /// @dev Throws if current period is less than the target activation period
  error ErrNotActivated(uint256 untilPeriod);
  /// @dev Throws if the cool down for key hash change is not ended
  error ErrNotEndedChangeKeyHashCooldown();
  /// @dev Throws if the cool down for registration is not ended
  error ErrNotEndedRegisterCooldown();
  /// @dev Throws if the proof is invalid
  error ErrInvalidProof();
  /// @dev Throws if the request is not finalized
  error ErrNotFinalizedBeacon(uint256 period);
  /// @dev Throws if the period is invalid (too early or too late)
  error ErrInvalidPeriod();
  /// @dev Throws if the request is already submitted
  error ErrAlreadySubmitted();
  /// @dev Throws if the request is already finalized
  error ErrAlreadyFinalizedBeacon(uint256 period);
  /// @dev Throws if the random request is inexistent
  error ErrInvalidRandomRequest(bytes32 expected, bytes32 actual);
  /// @dev Throws if the key hash is not match with the one in the profile
  error ErrInvalidKeyHash(bytes32 expected, bytes32 actual);
  /// @dev Throws if sum of all validator types threshold is not equal to max validator number
  error ErrInvalidThresholdConfig();
  /// @dev Throws if the chain ID is invalid
  error ErrInvalidChainId(uint256 expected, uint256 actual);
  /// @dev Throws if the address of verifying contract is not match with current contract
  error ErrInvalidVerifyingContract(address expected, address actual);

  /**
   * @dev The validator type.
   */
  enum ValidatorType {
    Unknown,
    // Max Validator Number
    All,
    // Max Governing Validator Number
    Governing,
    // Max Standard Validator Number
    Standard,
    // Max Rotating Validator Number
    Rotating
  }

  /**
   * @dev The beacon struct.
   */
  struct Beacon {
    // The request hash.
    bytes32 reqHash;
    // The random beacon value.
    uint256 value;
    // Whether the beacon is finalized.
    bool finalized;
    // The submission count.
    uint32 submissionCount;
    // Mapping of submitted requests.
    mapping(address cid => bool) submitted;
  }

  /**
   * @dev Emitted when the validator threshold is updated.
   * @param validatorType The validator type.
   * @param threshold The new value.
   */
  event ValidatorThresholdUpdated(ValidatorType indexed validatorType, uint256 threshold);

  /**
   * @dev Emitted when the unavailability slash threshold is updated.
   * @param value The new value.
   */
  event SlashUnavailabilityThresholdUpdated(uint256 value);

  /**
   * @dev Emitted when the beacon is finalized.
   * @param period The period.
   * @param value The beacon value.
   */
  event BeaconFinalized(uint256 indexed period, uint256 value);

  /**
   * @dev Emitted when the random seed is fulfilled.
   * @param by The address that fulfill the random seed.
   * @param period The period.
   * @param reqHash The request hash.
   */
  event RandomSeedFulfilled(address indexed by, uint256 indexed period, bytes32 indexed reqHash);

  /**
   * @dev Emitted when the random seed is requested.
   * @param period The period.
   * @param reqHash The request hash.
   * @param req The random request.
   */
  event RandomSeedRequested(uint256 indexed period, bytes32 indexed reqHash, RandomRequest req);

  /**
   * @dev Threshold for the cooldown period of key hash change and newly registered candidates.
   */
  function COOLDOWN_PERIOD_THRESHOLD() external view returns (uint256 threshold);

  /**
   * @dev Request the random seed for the next period, at the first epoch of each period.
   *
   * Callback function of {RoninValidatorSet-wrapUpEpoch}, only called at the end of an period.
   */
  function execRequestRandomSeedForNextPeriod(uint256 lastUpdatedPeriod, uint256 newPeriod) external;

  /**
   * @dev Finalize the beacon and and pending cids for upcoming period.
   *
   * Callback function of {RoninValidatorSet-wrapUpEpoch}, only called at the end of an period.
   */
  function execWrapUpBeaconAndPendingCids(
    uint256 lastUpdatedPeriod,
    uint256 newPeriod,
    address[] calldata allCids
  ) external;

  /**
   * @dev Record the unavailability and slash the validator.
   *
   * Callback function of {RoninValidatorSet-wrapUpEpoch}, only called at the end of an period.
   */
  function execRecordAndSlashUnavailability(
    uint256 lastUpdatedPeriod,
    uint256 newPeriod,
    address slashIndicator,
    address[] calldata allCids
  ) external;

  /**
   * @dev Bulk set the pick thresholds for a given validator types.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the event `PickThresholdUpdated`.
   *
   * @param validatorTypes An array of validator types.
   * @param thresholds An array of threshold values.
   */
  function bulkSetValidatorThresholds(ValidatorType[] calldata validatorTypes, uint256[] calldata thresholds) external;

  /**
   * @dev Sets the unavailability slash threshold.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the event `SlashUnavailabilityThresholdUpdated`.
   *
   * @param slashThreshold The new value.
   */
  function setUnavailabilitySlashThreshold(uint256 slashThreshold) external;

  /**
   * @dev Fulfills the random seed.
   *
   * Requirements:
   * - The request is not finalized.
   * - The period is greater than current period.
   * - The chain id field is match with the current chain ID.
   * - The verifying contract field is match with the current contract address.
   * - The proof is valid.
   * - The request is not submitted by method caller before.
   * - The key hash is match with the one in the profile.
   * - The key hash changed cool down is ended.
   * - The method caller is governance validator.
   * - The method caller is not newly joined.
   *
   * Emits the event `RandomSeedFulfilled`.
   *
   * @param req The random request.
   * @param proof The VRF proof.
   */
  function fulfillRandomSeed(RandomRequest calldata req, VRF.Proof calldata proof) external;

  /**
   * @dev Checks if a submission has been made by a specific oracle for a given period.
   * @param period The period to check for the submission.
   * @param consensus The consensus address of governing validator.
   * @return submitted A boolean indicating whether the submission has been made or not.
   */
  function isSubmittedAt(uint256 period, TConsensus consensus) external view returns (bool submitted);

  /**
   * @dev Checks if a submission has been made by a specific oracle for a given period.
   * @param period The period to check for the submission.
   * @param cid The candidate id of governing validator.
   * @return A boolean indicating whether the submission has been made or not.
   */
  function isSubmittedAtById(uint256 period, address cid) external view returns (bool);

  /**
   * @dev Checks if a submission has been made by a specific key hash for a given period.
   * @param period The period to check for the submission.
   * @param keyHash The key hash of the governing validator.
   * @return submitted A boolean indicating whether the submission has been made or not.
   */
  function isSubmittedAtByKeyHash(uint256 period, bytes32 keyHash) external view returns (bool submitted);

  /**
   * @dev Calculates the key hash from public keys.
   */
  function calcKeyHash(uint256[2] memory publicKeys) external pure returns (bytes32 keyHash);

  /**
   * @dev Get request hash for a given period.
   */
  function getRequestHash(uint256 period) external view returns (bytes32 reqHash);

  /**
   * @dev Get last finalized period.
   */
  function getLastFinalizedPeriod() external view returns (uint256 period);

  /**
   * @dev Returns the unavailability slash threshold.
   */
  function getUnavailabilitySlashThreshold() external view returns (uint256 threshold);

  /**
   * @dev Returns the pick threshold for a given validator type.
   * @param validatorType The validator type.
   * @return threshold The pick threshold.
   */
  function getValidatorThreshold(ValidatorType validatorType) external view returns (uint256 threshold);

  /**
   * @dev Retrieves the beacon data for a given period.
   * @param period The period for which to retrieve the beacon data.
   * @return value The beacon value for the given period.
   * @return finalized A boolean indicating whether the beacon value has been finalized.
   * @return submissionCount The number of submissions for the given period.
   */
  function getBeaconData(uint256 period) external view returns (uint256 value, bool finalized, uint256 submissionCount);

  /**
   * @dev Retrieves the unavailability count for a given consensus address.
   */
  function getUnavailabilityCount(TConsensus consensus) external view returns (uint256 count);

  /**
   * @dev Retrieves the unavailability count for a given candidate id.
   */
  function getUnavailabilityCountById(address cid) external view returns (uint256 count);

  /**
   * @dev Returns the period at which the random beacon sorting was activated.
   */
  function getActivatedAtPeriod() external view returns (uint256 activatedPeriod);

  /**
   * @dev Picks validator IDs for given `epoch` number.
   */
  function pickValidatorSetForCurrentPeriod(uint256 epoch) external view returns (address[] memory pickedCids);

  /**
   * @dev Get pending validator ids that will be chosen in given `period`.
   */
  function getSavedValidatorSet(uint256 period)
    external
    view
    returns (LibSortValidatorsByBeacon.ValidatorStorage memory savedValidators);

  /**
   * @dev Get selected validator ids that have been chosen in given `period` and `epoch`.
   */
  function getSelectedValidatorSet(uint256 period, uint256 epoch) external view returns (address[] memory pickedCids);
}
