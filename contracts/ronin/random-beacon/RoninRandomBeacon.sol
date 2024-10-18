// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { VRF } from "@chainlink/contracts/src/v0.8/VRF.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { HasContracts } from "../../extensions/collections/HasContracts.sol";
import { GlobalConfigConsumer } from "../../extensions/consumers/GlobalConfigConsumer.sol";
import { IProfile } from "../../interfaces/IProfile.sol";
import { IStaking } from "../../interfaces/staking/IStaking.sol";
import { IRandomBeacon } from "../../interfaces/random-beacon/IRandomBeacon.sol";
import { ICandidateManager } from "../../interfaces/validator/ICandidateManager.sol";
import { ITimingInfo } from "../../interfaces/validator/info-fragments/ITimingInfo.sol";
import { IRoninTrustedOrganization } from "../../interfaces/IRoninTrustedOrganization.sol";
import { ISlashRandomBeacon } from "../../interfaces/slash-indicator/ISlashRandomBeacon.sol";
import { LibSLA, RandomRequest } from "../../libraries/LibSLA.sol";
import { LibSortValidatorsByBeacon } from "../../libraries/LibSortValidatorsByBeacon.sol";
import { TConsensus } from "../../udvts/Types.sol";
import { ContractType } from "../../utils/ContractType.sol";
import { ErrLengthMismatch, ErrUnauthorizedCall } from "../../utils/CommonErrors.sol";

abstract contract RoninRandomBeacon is Initializable, VRF, HasContracts, GlobalConfigConsumer, IRandomBeacon {
  using LibSLA for uint256[2];

  /// @dev Storage gap for future upgrades.
  uint256[50] private __gap;

  /// @dev The threshold of cooldown period for key hash change and newly register candidates.
  uint256 internal constant _COOLDOWN_PERIOD_THRESHOLD = 1;
  /// @dev The block number where the logic contract is deployed.
  uint256 private immutable _LOGIC_DEPLOYED_AT_BLOCK;

  /// @dev Period of the beacon validator selection is activated.
  uint256 internal _activatedAtPeriod;
  /// @dev Latest period where random beacon is finalized.
  uint256 internal _lastFinalizedPeriod;
  /// @dev The threshold of unavailability to slash.
  uint256 internal _unavailabilitySlashThreshold;
  /// @dev Mapping of consecutive unavailable count per validator.
  mapping(address gvCid => uint256 count) internal _unavailableCount;
  /// @dev Mapping of beacon per period.
  mapping(uint256 period => Beacon beacon) internal _beaconPerPeriod;
  /// @dev The maximum pick threshold for validator type.
  mapping(ValidatorType validatorType => uint256 threshold) internal _validatorThreshold;

  modifier onlyActivated(
    uint256 period
  ) {
    if (period < _activatedAtPeriod) return;
    _;
  }

  constructor() {
    _disableInitializers();
    _LOGIC_DEPLOYED_AT_BLOCK = block.number;
  }

  function initialize(
    address profile,
    address staking,
    address trustedOrg,
    address validatorSet,
    uint256 slashThreshold,
    uint256 activatedAtPeriod,
    ValidatorType[] calldata validatorTypes,
    uint256[] calldata thresholds
  ) external initializer {
    bytes32 initialSeed =
      keccak256(abi.encode(blockhash(_LOGIC_DEPLOYED_AT_BLOCK), block.coinbase, block.timestamp, block.chainid));

    _activatedAtPeriod = activatedAtPeriod;
    _setUnavailabilitySlashThreshold(slashThreshold);
    _bulkSetValidatorThresholds(validatorTypes, thresholds);
    _requestRandomSeed(activatedAtPeriod, uint256(initialSeed));

    _setContract(ContractType.PROFILE, profile);
    _setContract(ContractType.STAKING, staking);
    _setContract(ContractType.VALIDATOR, validatorSet);
    _setContract(ContractType.RONIN_TRUSTED_ORGANIZATION, trustedOrg);
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function bulkSetValidatorThresholds(
    ValidatorType[] calldata validatorTypes,
    uint256[] calldata thresholds
  ) external onlyAdmin {
    _bulkSetValidatorThresholds(validatorTypes, thresholds);
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function setUnavailabilitySlashThreshold(
    uint256 threshold
  ) external onlyAdmin {
    _setUnavailabilitySlashThreshold(threshold);
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function fulfillRandomSeed(RandomRequest calldata req, Proof calldata proof) external {
    unchecked {
      bytes32 reqHash = req.hash();
      bytes32 keyHash = proof.pk.calcKeyHash();

      IProfile profile = IProfile(getContract(ContractType.PROFILE));

      // Already checked in Profile:
      // 1. If `cid` not exit, revert the whole tx,
      // 2. Allow both GV and SV to submit the seed.
      (address cid, uint256 keyLastChange, uint256 profileRegisteredAt) =
        profile.getVRFKeyHash2BeaconInfo({ vrfKeyHash: keyHash });
      uint256 currPeriod = ITimingInfo(getContract(ContractType.VALIDATOR)).currentPeriod();

      Beacon storage $beacon = _beaconPerPeriod[req.period];

      _requireValidRequest(req, $beacon, currPeriod, reqHash);
      _requireAuthorized(cid, profileRegisteredAt, currPeriod);
      _requireValidProof(req, proof, currPeriod, keyHash, keyLastChange);

      // randomness should not be re-submitted
      if ($beacon.submitted[cid]) revert ErrAlreadySubmitted();

      $beacon.submissionCount++;
      $beacon.submitted[cid] = true;
      $beacon.value ^= VRF.randomValueFromVRFProof(proof, proof.seed);

      emit RandomSeedFulfilled(msg.sender, req.period, reqHash);
    }
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function execRequestRandomSeedForNextPeriod(
    uint256 lastUpdatedPeriod,
    uint256 newPeriod
  ) external onlyContract(ContractType.VALIDATOR) onlyActivated(newPeriod) {
    unchecked {
      bool isPeriodEnding = lastUpdatedPeriod < newPeriod;
      if (isPeriodEnding) return;

      // Request the next random seed if it has not been requested at the start epoch of the period
      uint256 nextPeriod = lastUpdatedPeriod + 1;
      if (_beaconPerPeriod[nextPeriod].reqHash == 0) {
        _requestRandomSeed(nextPeriod, _beaconPerPeriod[lastUpdatedPeriod].value);
      }
    }
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function execFinalizeBeaconAndPendingCids(
    uint256 lastUpdatedPeriod,
    uint256 newPeriod,
    address[] calldata allCids
  ) external onlyContract(ContractType.VALIDATOR) onlyActivated(newPeriod) {
    Beacon storage $beacon = _beaconPerPeriod[newPeriod];

    address[] memory cids = _filterOutNewlyJoinedValidators({ currPeriod: lastUpdatedPeriod, allCids: allCids });
    uint256[] memory trustedWeights =
      IRoninTrustedOrganization(getContract(ContractType.RONIN_TRUSTED_ORGANIZATION)).getConsensusWeightsById(cids);

    _finalizeBeacon($beacon, newPeriod);

    LibSortValidatorsByBeacon.filterAndSaveValidators({
      period: newPeriod,
      nGV: _validatorThreshold[ValidatorType.Governing],
      nSV: _validatorThreshold[ValidatorType.Standard],
      nRV: _validatorThreshold[ValidatorType.Rotating],
      cids: cids,
      trustedWeights: trustedWeights,
      stakedAmounts: IStaking(getContract(ContractType.STAKING)).getManyStakingTotalsById(cids)
    });
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function execRecordAndSlashUnavailability(
    uint256 lastUpdatedPeriod,
    uint256 newPeriod,
    address slashIndicator,
    address[] calldata allCids
  ) external onlyContract(ContractType.VALIDATOR) onlyActivated(lastUpdatedPeriod) {
    Beacon storage $beacon = _beaconPerPeriod[newPeriod];

    address[] memory cids = _filterOutNewlyJoinedValidators({ currPeriod: lastUpdatedPeriod, allCids: allCids });
    uint256[] memory trustedWeights =
      IRoninTrustedOrganization(getContract(ContractType.RONIN_TRUSTED_ORGANIZATION)).getConsensusWeightsById(cids);

    _recordAndSlashUnavailability($beacon, lastUpdatedPeriod, slashIndicator, cids, trustedWeights);
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function pickValidatorSetForCurrentPeriod(
    uint256 epoch
  ) external view returns (address[] memory pickedCids) {
    pickedCids = getSelectedValidatorSet({ period: _computePeriod(block.timestamp), epoch: epoch });
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function getSelectedValidatorSet(uint256 period, uint256 epoch) public view returns (address[] memory pickedCids) {
    Beacon storage $beacon = _beaconPerPeriod[period];
    if (!$beacon.finalized) revert ErrNotFinalizedBeacon(period);

    pickedCids = LibSortValidatorsByBeacon.pickValidatorSet(period, epoch, $beacon.value);
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function getSavedValidatorSet(
    uint256 period
  ) external view returns (LibSortValidatorsByBeacon.ValidatorStorage memory) {
    Beacon storage $beacon = _beaconPerPeriod[period];
    if (!$beacon.finalized) revert ErrNotFinalizedBeacon(period);

    return LibSortValidatorsByBeacon.getSavedValidatorSet({ period: period });
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function getActivatedAtPeriod() external view returns (uint256) {
    return _activatedAtPeriod;
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function getLastFinalizedPeriod() external view returns (uint256) {
    return _lastFinalizedPeriod;
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function getRequestHash(
    uint256 period
  ) external view returns (bytes32 reqHash) {
    reqHash = _beaconPerPeriod[period].reqHash;
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function isSubmittedAt(uint256 period, TConsensus consensus) external view returns (bool submitted) {
    submitted = isSubmittedAtById({ period: period, cid: _convertToCid(consensus) });
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function isSubmittedAtByKeyHash(uint256 period, bytes32 keyHash) external view returns (bool submitted) {
    IProfile profile = IProfile(getContract(ContractType.PROFILE));
    address cid = profile.getVRFKeyHash2Id({ vrfKeyHash: keyHash });
    submitted = isSubmittedAtById(period, cid);
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function isSubmittedAtById(uint256 period, address cid) public view returns (bool submitted) {
    submitted = _beaconPerPeriod[period].submitted[cid];
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function getBeaconData(
    uint256 period
  ) external view returns (uint256 value, bool finalized, uint256 submissionCount) {
    Beacon storage $beacon = _beaconPerPeriod[period];
    value = $beacon.value;
    finalized = $beacon.finalized;
    submissionCount = $beacon.submissionCount;
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function COOLDOWN_PERIOD_THRESHOLD() public pure virtual returns (uint256 threshold) {
    threshold = _COOLDOWN_PERIOD_THRESHOLD;
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function getUnavailabilityCount(
    TConsensus consensus
  ) external view returns (uint256 count) {
    count = getUnavailabilityCountById({ cid: _convertToCid(consensus) });
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function getUnavailabilityCountById(
    address cid
  ) public view returns (uint256 count) {
    count = _unavailableCount[cid];
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function getValidatorThreshold(
    ValidatorType validatorType
  ) external view returns (uint256 threshold) {
    threshold = _validatorThreshold[validatorType];
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function getUnavailabilitySlashThreshold() external view returns (uint256 threshold) {
    threshold = _unavailabilitySlashThreshold;
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function calcKeyHash(
    uint256[2] memory publicKeys
  ) external pure returns (bytes32 keyHash) {
    keyHash = LibSLA.calcKeyHash(publicKeys);
  }

  /**
   * @dev Requests a random seed for a given period and previous beacon.
   * @param period The period for which the random seed is requested.
   * @param prevBeacon The previous beacon value.
   */
  function _requestRandomSeed(uint256 period, uint256 prevBeacon) internal {
    RandomRequest memory req = RandomRequest({
      period: period,
      prevBeacon: prevBeacon,
      chainId: block.chainid,
      verifyingContract: address(this)
    });
    bytes32 reqHash = req.hash();

    _beaconPerPeriod[req.period].reqHash = reqHash;

    emit RandomSeedRequested(period, reqHash, req);
  }

  /**
   * @dev Finalizes the beacon by marking it as finalized and emitting an event.
   * @param $beacon The beacon to be finalized.
   * @param period The period of the beacon.
   */
  function _finalizeBeacon(Beacon storage $beacon, uint256 period) internal {
    $beacon.finalized = true;
    _lastFinalizedPeriod = period;

    emit BeaconFinalized(period, $beacon.value);
  }

  /**
   * @dev Sets the unavailability slash threshold.
   */
  function _setUnavailabilitySlashThreshold(
    uint256 threshold
  ) internal {
    _unavailabilitySlashThreshold = threshold;

    emit SlashUnavailabilityThresholdUpdated(threshold);
  }

  /**
   * @dev Records and slashes the unavailability of the beacon.
   * @param $beacon The storage reference to the Beacon struct.
   * @param lastUpdatedPeriod The last updated period in the validator contract.
   */
  function _recordAndSlashUnavailability(
    Beacon storage $beacon,
    uint256 lastUpdatedPeriod,
    address slashIndicator,
    address[] memory cids,
    uint256[] memory trustedWeights
  ) internal onlyActivated(lastUpdatedPeriod) {
    unchecked {
      address cid;
      uint256 unavailableCount;
      uint256 length = cids.length;
      uint256 slashThreshold = _unavailabilitySlashThreshold;

      // Iterate through trusted organizations
      for (uint256 i; i < length; ++i) {
        if (trustedWeights[i] != 0) {
          cid = cids[i];
          unavailableCount = _unavailableCount[cid];

          // If the validator submits the vrf proof, clear current slash counter.
          if ($beacon.submitted[cid]) {
            if (unavailableCount != 0) {
              delete _unavailableCount[cid];
            }
            continue;
          }

          // If missing proof, increment the consecutive unavailable count and check if it exceeds the threshold
          _unavailableCount[cid] = ++unavailableCount;
          if (unavailableCount >= slashThreshold) {
            ISlashRandomBeacon(slashIndicator).slashRandomBeacon(cid, lastUpdatedPeriod);
            // Delete the count if the validator has been slashed
            delete _unavailableCount[cid];
          }
        }
      }
    }
  }

  /**
   * @dev Sets the thresholds for multiple validator types.
   * @notice Emits a `ValidatorThresholdUpdated` event .
   */
  function _bulkSetValidatorThresholds(ValidatorType[] calldata validatorTypes, uint256[] calldata thresholds) internal {
    uint256 length = validatorTypes.length;
    if (length != thresholds.length) revert ErrLengthMismatch(msg.sig);

    uint256 threshold;
    ValidatorType validatorType;

    for (uint256 i; i < length; ++i) {
      validatorType = validatorTypes[i];
      threshold = thresholds[i];

      _validatorThreshold[validatorType] = threshold;

      emit ValidatorThresholdUpdated(validatorType, threshold);
    }

    if (
      _validatorThreshold[ValidatorType.Governing] + _validatorThreshold[ValidatorType.Standard]
        + _validatorThreshold[ValidatorType.Rotating] != _validatorThreshold[ValidatorType.All]
    ) {
      revert ErrInvalidThresholdConfig();
    }
  }

  /**
   * @dev Filters out the newly joined validators based on the provided threshold.
   */
  function _filterOutNewlyJoinedValidators(
    uint256 currPeriod,
    address[] calldata allCids
  ) internal view returns (address[] memory validCids) {
    unchecked {
      uint256 count;
      uint256 threshold = COOLDOWN_PERIOD_THRESHOLD();
      uint256[] memory registeredAts = IProfile(getContract(ContractType.PROFILE)).getManyId2RegisteredAt(allCids);
      uint256 length = allCids.length;
      validCids = new address[](length);

      for (uint256 i; i < length; ++i) {
        if (_computePeriod(registeredAts[i]) + threshold <= currPeriod) {
          validCids[count++] = allCids[i];
        }
      }

      assembly {
        mstore(validCids, count)
      }
    }
  }

  /**
   * @dev Requirements for valid proof:
   *
   * - Key hash should not be changed within the cooldown period.
   * - Proof should be valid.
   */
  function _requireValidProof(
    RandomRequest calldata req,
    Proof calldata proof,
    uint256 currPeriod,
    bytes32 keyHash,
    uint256 keyLastChange
  ) internal pure {
    // key hash should not be changed within the cooldown period
    if (_computePeriod(keyLastChange) + COOLDOWN_PERIOD_THRESHOLD() > currPeriod) {
      revert ErrNotEndedChangeKeyHashCooldown();
    }

    // proof should be valid
    if (req.calcProofSeed(keyHash) != proof.seed) revert ErrInvalidProof();
  }

  /**
   * @dev Requirements for authorized fulfill random seed:
   *
   * - Sender is governing validator.
   * - Sender's profile is not newly registered.
   */
  function _requireAuthorized(address cid, uint256 profileRegisteredAt, uint256 currPeriod) internal view {
    address trustedOrg = getContract(ContractType.RONIN_TRUSTED_ORGANIZATION);

    // only allow to fulfill if the sender is a governing validator
    if (IRoninTrustedOrganization(trustedOrg).getConsensusWeightById(cid) == 0) {
      revert ErrUnauthorizedCall(msg.sig);
    }

    // only allow to fulfill if the candidate is not newly registered
    if (_computePeriod(profileRegisteredAt) + COOLDOWN_PERIOD_THRESHOLD() > currPeriod) {
      revert ErrNotEndedRegisterCooldown();
    }
  }

  /**
   * @dev Requirements for valid random request:
   *
   * - Beacon must not be finalized.
   * - Period in Request must be greater than current period.
   * - Period in Request must be greater than the `_activatedAtPeriod`.
   * - Submitted Request hash must match the hash in storage.
   */
  function _requireValidRequest(
    RandomRequest calldata req,
    Beacon storage $beacon,
    uint256 currPeriod,
    bytes32 reqHash
  ) internal view {
    // Verify the request with current chain context
    if (req.chainId != block.chainid) revert ErrInvalidChainId({ expected: block.chainid, actual: req.chainId });
    if (req.verifyingContract != address(this)) {
      revert ErrInvalidVerifyingContract({ expected: address(this), actual: req.verifyingContract });
    }

    // period should be valid
    if (req.period <= currPeriod) revert ErrInvalidPeriod();
    if (req.period < _activatedAtPeriod) revert ErrNotActivated(req.period);

    // beacon should not be finalized
    if ($beacon.finalized) revert ErrAlreadyFinalizedBeacon(req.period);

    bytes32 expectedReqHash = $beacon.reqHash;
    // request hash should be valid
    if (expectedReqHash != reqHash) revert ErrInvalidRandomRequest(expectedReqHash, reqHash);
  }

  /**
   * @dev Converts the consensus address to cid from `Profile` contract.
   */
  function _convertToCid(
    TConsensus consensus
  ) internal view returns (address) {
    return IProfile(getContract(ContractType.PROFILE)).getConsensus2Id({ consensus: consensus });
  }

  /**
   * @dev See {TimingStorage-_computePeriod}.
   *
   * This duplicates the implementation in {RoninValidatorSet-_computePeriod} to reduce external calls.
   */
  function _computePeriod(
    uint256 timestamp
  ) internal pure returns (uint256) {
    return timestamp / PERIOD_DURATION;
  }
}
