// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { RandomRequest } from "../../libraries/LibSLA.sol";
import { VRF } from "@chainlink/contracts/src/v0.8/dev/VRF.sol";

interface IRandomBeacon {
  /// @dev Throws if current period is less than the target activation period
  error ErrNotActivated(uint256 untilPeriod);
  /// @dev Throws if the cool down for key hash change is not ended
  error ErrKeyHashChangeCooldownNotEnded();
  /// @dev Throws if the cool down for registration is not ended
  error ErrRegisterCoolDownNotEnded();
  /// @dev Throws if the proof is invalid
  error ErrInvalidProof();
  /// @dev Throws if the request is not finalized
  error ErrBeaconNotFinalized(uint256 period);
  /// @dev Throws if the period is invalid (too early or too late)
  error ErrInvalidPeriod();
  /// @dev Throws if the request is already submitted
  error ErrAlreadySubmitted();
  /// @dev Throws if the request is already finalized
  error ErrBeaconAlreadyFinalized(uint256 period);
  /// @dev Throws if the random request is unexists
  error ErrInvalidRandomRequest(bytes32 expected, bytes32 got);
  /// @dev Throws if the key hash is not match with the one in the profile
  error ErrInvalidKeyHash(bytes32 expected, bytes32 actual);

  /**
   * @dev The validator type.
   */
  enum ValidatorType {
    Unknown,
    // Max Validator Number
    All,
    // Max Governance Validator Number
    Governance,
    // Max Standard Validator Number
    Standard,
    // Max Rotating Validator Number
    Rotate
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
   * @dev Callback function called at the end of an epoch to wrap up the current epoch and start a new one.
   * @param lastPeriod The index of the last period in the current epoch.
   * @param newPeriod The index of the first period in the new epoch.
   *
   * if period is ending, finalize the beacon and record the unavailability
   * if period is not ending and at the start of period, request the random seed for the next period
   */
  function onWrapUpEpoch(uint256 lastPeriod, uint256 newPeriod) external;

  /**
   * @dev Bulk set the pick thresholds for a given validator types.
   * @param validatorTypes An array of validator types.
   * @param thresholds An array of threshold values.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the event `PickThresholdUpdated`.
   *
   */
  function bulkSetValidatorThresholds(ValidatorType[] calldata validatorTypes, uint256[] calldata thresholds) external;

  /**
   * @dev Sets the unavailability slash threshold.
   * @param slashThreshold The new value.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the event `SlashUnavailabilityThresholdUpdated`.
   *
   */
  function setUnavailabilitySlashThreshold(uint256 slashThreshold) external;

  /**
   * @dev Fulfills the random seed.
   * @param req The random request.
   * @param proof The VRF proof.
   *
   * Requirements:
   * - The request is not finalized.
   * - The period is greater than current period.
   * - The proof is valid.
   * - The request is not submitted by method caller before.
   * - The key hash is match with the one in the profile.
   * - The key hash changed cool down is ended.
   * - The method caller is governance validator.
   * - The nethod caller is not newly joined.
   *
   * Emits the event `RandomSeedFulfilled`.
   *
   */
  function fulfillRandomSeed(RandomRequest calldata req, VRF.Proof calldata proof) external;

  /**
   * @dev Checks if a submission has been made by a specific oracle for a given period.
   * @param period The period to check for the submission.
   * @param oracle The address of the oracle/consensus to check for the submission.
   * @return A boolean indicating whether the submission has been made or not.
   */
  function isSubmittedAt(uint256 period, address oracle) external view returns (bool);

  /**
   * @dev Returns the unavailability slash threshold.
   */
  function getUnavailabilitySlashThreshold() external view returns (uint256);

  /**
   * @dev Returns the pick threshold for a given validator type.
   * @param validatorType The validator type.
   * @return The pick threshold.
   */
  function getValidatorThreshold(ValidatorType validatorType) external view returns (uint256);

  /**
   * @dev Retrieves the beacon value for a given period.
   * @param period The period for which to retrieve the beacon value.
   * @return value The beacon value for the given period.
   * @return finalized A boolean indicating whether the beacon value has been finalized.
   */
  function getBeacon(uint256 period) external view returns (uint256 value, bool finalized);

  /**
   * @dev Retrieves the unavailability count for a given candidate id.
   */
  function getUnavailabilityCount(address cid) external view returns (uint256);

  /**
   * @dev Returns the period at which the random beacon sorting was activated.
   */
  function getActivatedAtPeriod() external view returns (uint256);

  /**
   * @dev Picks validator IDs for given epoch number.
   */
  function pickValidatorSet(uint256 epoch) external view returns (address[] memory pickedCids);
}
