// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { VRF } from "@chainlink/contracts/src/v0.8/dev/VRF.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { HasContracts } from "../../extensions/collections/HasContracts.sol";
import { GlobalConfigConsumer } from "../../extensions/consumers/GlobalConfigConsumer.sol";
import { PCUSortValidatorsByBeacon } from "../../precompile-usages/PCUSortValidatorsByBeacon.sol";
import { IStaking } from "../../interfaces/staking/IStaking.sol";
import { IProfile } from "../../interfaces/IProfile.sol";
import { IRandomBeacon } from "../../interfaces/random-beacon/IRandomBeacon.sol";
import { ICandidateManager } from "../../interfaces/validator/ICandidateManager.sol";
import { ITimingInfo } from "../../interfaces/validator/info-fragments/ITimingInfo.sol";
import { IRoninTrustedOrganization } from "../../interfaces/IRoninTrustedOrganization.sol";
import { ISlashRandomBeacon } from "../../interfaces/slash-indicator/ISlashRandomBeacon.sol";
import { IValidatorInfoV2 } from "../../interfaces/validator/info-fragments/IValidatorInfoV2.sol";
import { LibSLA, RandomRequest } from "../../libraries/LibSLA.sol";
import { TConsensus } from "../../udvts/Types.sol";
import { ContractType } from "../../utils/ContractType.sol";
import { ErrLengthMismatch, ErrUnauthorizedCall } from "../../utils/CommonErrors.sol";

contract RoninRandomBeacon is
  Initializable,
  VRF,
  HasContracts,
  GlobalConfigConsumer,
  PCUSortValidatorsByBeacon,
  IRandomBeacon
{
  using LibSLA for uint256[2];

  uint256[50] private __gap;

  /// @dev The threshold of cooldown period for key hash change and newly register candidates.
  uint256 private constant COOLDOWN_PERIOD_THRESHOLD = 1;

  /// @dev Period of the beacon validator selection is activated.
  uint256 private _activatedAtPeriod;
  /// @dev The threshold of unavailability to slash.
  uint256 private _unavailabilitySlashThreshold;
  /// @dev Mapping of consecutive unavailable count per validator.
  mapping(address gvId => uint256 count) private _unavailableCount;
  /// @dev Mapping of beacon per period.
  mapping(uint256 period => Beacon beacon) private _beaconPerPeriod;
  /// @dev The maximum pick threshold for validator type.
  mapping(ValidatorType validatorType => uint256 threshold) private _validatorThreshold;

  constructor() {
    _disableInitializers();
  }

  function initialize(
    address profile,
    address staking,
    address trustedOrg,
    address validatorSet,
    address slashIndicator,
    uint256 slashThreshold,
    uint256 initialSeed,
    uint256 activatedAtPeriod,
    ValidatorType[] calldata validatorTypes,
    uint256[] calldata thresholds
  ) external initializer {
    _activatedAtPeriod = activatedAtPeriod;
    _setUnavailabilitySlashThreshold(slashThreshold);
    _requestRandomSeed(activatedAtPeriod, initialSeed);
    _bulkSetValidatorThresholds(validatorTypes, thresholds);

    _setContract(ContractType.PROFILE, profile);
    _setContract(ContractType.STAKING, staking);
    _setContract(ContractType.VALIDATOR, validatorSet);
    _setContract(ContractType.SLASH_INDICATOR, slashIndicator);
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
  function setUnavailabilitySlashThreshold(uint256 threshold) external onlyAdmin {
    _setUnavailabilitySlashThreshold(threshold);
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function fulfillRandomSeed(RandomRequest calldata req, Proof calldata proof) external {
    // period should be valid
    uint256 currentPeriod = ITimingInfo(getContract(ContractType.VALIDATOR)).currentPeriod();
    if (req.period <= currentPeriod) revert ErrInvalidPeriod();
    if (req.period <= _activatedAtPeriod) revert ErrNotActivated(req.period);

    IProfile profile = IProfile(getContract(ContractType.PROFILE));
    address oracle = msg.sender;
    address cid = profile.getConsensus2Id({ consensus: TConsensus.wrap(oracle) });
    // only governance validator can fulfill the random seed
    if (
      IRoninTrustedOrganization(getContract(ContractType.RONIN_TRUSTED_ORGANIZATION)).getConsensusWeightById(cid) != 0
    ) {
      revert ErrUnauthorizedCall(msg.sig);
    }
    // only allow to fulfill if the candidate is not newly registered
    if (currentPeriod - _toPeriod(profile.getId2RegisteredAt(cid)) < COOLDOWN_PERIOD_THRESHOLD) {
      revert ErrRegisterCoolDownNotEnded();
    }

    // key hash should be the same as the one in the profile
    bytes32 keyHash = proof.pk.hash();
    if (currentPeriod - _toPeriod(profile.getId2VRFKeyHashLastChange(cid)) < COOLDOWN_PERIOD_THRESHOLD) {
      revert ErrKeyHashChangeCooldownNotEnded();
    }
    bytes32 expectedKeyHash = profile.getId2VRFKeyHash(cid);
    if (expectedKeyHash != keyHash) revert ErrInvalidKeyHash(expectedKeyHash, keyHash);

    // proof should be valid
    if (req.calcProofSeed(keyHash, oracle) != proof.seed) revert ErrInvalidProof();
    uint256 seed = VRF.randomValueFromVRFProof(proof, proof.seed);

    Beacon storage $beacon = _beaconPerPeriod[req.period];
    // request hash should be valid
    bytes32 reqHash = req.hash();
    bytes32 expectedReqHash = $beacon.reqHash;
    if (expectedReqHash != reqHash) revert ErrInvalidRandomRequest(expectedKeyHash, reqHash);

    // randomness should not be re-submitted
    if (_isSubmitted($beacon, cid)) revert ErrAlreadySubmitted();
    // beacon should not be finalized
    if ($beacon.finalized) revert ErrBeaconAlreadyFinalized(req.period);

    $beacon.value ^= seed;
    $beacon.submitted[cid] = true;

    emit RandomSeedFulfilled(oracle, req.period, reqHash);
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function onWrapUpEpoch(uint256 lastUpdatedPeriod, uint256 newPeriod) external onlyContract(ContractType.VALIDATOR) {
    // skip if the random beacon sorting is not activated
    if (lastUpdatedPeriod < _activatedAtPeriod) return;

    unchecked {
      bool periodEnding = newPeriod > lastUpdatedPeriod;

      if (periodEnding) {
        Beacon storage $beacon = _beaconPerPeriod[newPeriod];

        address[] memory cids =
          _filterOutNewlyJoinedValidators({ validator: msg.sender, currentPeriod: lastUpdatedPeriod });
        uint256[] memory trustedWeights =
          IRoninTrustedOrganization(getContract(ContractType.RONIN_TRUSTED_ORGANIZATION)).getConsensusWeightsById(cids);

        _finalizeBeacon($beacon, newPeriod);
        _recordAndSlashUnavailiblity($beacon, lastUpdatedPeriod, cids, trustedWeights);
        _pcRequestSortValidatorSet({
          beacon: $beacon.value,
          period: newPeriod,
          numGovernanceValidator: _validatorThreshold[ValidatorType.Governance],
          numStandardValidator: _validatorThreshold[ValidatorType.Standard],
          numRotatingValidator: _validatorThreshold[ValidatorType.Rotate],
          cids: cids,
          trustedWeights: trustedWeights,
          stakedAmounts: IStaking(getContract(ContractType.STAKING)).getManyStakingTotalsById(cids)
        });

        return;
      }

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
  function pickValidatorSet(uint256 epoch)
    external
    view
    onlyContract(ContractType.VALIDATOR)
    returns (address[] memory pickedCids)
  {
    address validator = getContract(ContractType.VALIDATOR);
    uint256 currentPeriod = ITimingInfo(validator).currentPeriod();

    // handle legacy sorting method
    if (currentPeriod < _activatedAtPeriod) return IValidatorInfoV2(validator).getValidatorIds();

    uint256 period;
    uint256 epochIndex;

    if (ITimingInfo(validator).isPeriodEnding()) {
      epochIndex = 0;
      period = currentPeriod + 1;
    } else {
      period = currentPeriod;
      uint256 startBlock = ITimingInfo(validator).currentPeriodStartAtBlock();
      uint256 startEpoch = ITimingInfo(validator).epochOf(startBlock);
      epochIndex = epoch - startEpoch;
    }

    if (!_beaconPerPeriod[period].finalized) revert ErrBeaconNotFinalized(period);
    pickedCids = _pcPickValidatorSet(period, epochIndex);
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
  function isSubmittedAt(uint256 period, address oracle) external view returns (bool submitted) {
    IProfile profile = IProfile(getContract(ContractType.PROFILE));
    address cid = profile.getConsensus2Id({ consensus: TConsensus.wrap(oracle) });
    submitted = _isSubmitted(_beaconPerPeriod[period], cid);
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function getBeacon(uint256 period) public view returns (uint256 value, bool finalized) {
    Beacon storage $beacon = _beaconPerPeriod[period];
    value = $beacon.value;
    finalized = $beacon.finalized;
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function getUnavailabilityCount(address cid) external view returns (uint256) {
    return _unavailableCount[cid];
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function getValidatorThreshold(ValidatorType validatorType) external view returns (uint256) {
    return _validatorThreshold[validatorType];
  }

  /**
   * @inheritdoc IRandomBeacon
   */
  function getUnavailabilitySlashThreshold() external view returns (uint256) {
    return _unavailabilitySlashThreshold;
  }

  /**
   * @dev Requests a random seed for a given period and previous beacon.
   * @param period The period for which the random seed is requested.
   * @param prevBeacon The previous beacon value.
   */
  function _requestRandomSeed(uint256 period, uint256 prevBeacon) internal {
    RandomRequest memory req = RandomRequest({ period: period, prevBeacon: prevBeacon });
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

    emit BeaconFinalized(period, $beacon.value);
  }

  /**
   * @dev Sets the unavailability slash threshold.
   */
  function _setUnavailabilitySlashThreshold(uint256 threshold) internal {
    _unavailabilitySlashThreshold = threshold;

    emit SlashUnavailabilityThresholdUpdated(threshold);
  }

  /**
   * @dev Records and slashes the unavailability of the beacon.
   * @param $beacon The storage reference to the Beacon struct.
   * @param lastUpdatedPeriod The last updated period in the validator contract.
   */
  function _recordAndSlashUnavailiblity(
    Beacon storage $beacon,
    uint256 lastUpdatedPeriod,
    address[] memory cids,
    uint256[] memory trustedWeights
  ) internal {
    unchecked {
      if (lastUpdatedPeriod < _activatedAtPeriod) return;
      ISlashRandomBeacon slashIndicator = ISlashRandomBeacon(getContract(ContractType.SLASH_INDICATOR));

      address id;
      uint256 unavailableCount;
      uint256 length = cids.length;
      uint256 slashThreshold = _unavailabilitySlashThreshold;

      // Iterate through trusted organizations
      for (uint256 i; i < length; ++i) {
        if (trustedWeights[i] != 0) {
          id = cids[i];
          unavailableCount = _unavailableCount[id];

          // Check if the vrf proof has been submitted
          if (_isSubmitted($beacon, id)) {
            if (unavailableCount != 0) delete _unavailableCount[id];
          } else {
            // Increment the consecutive unavailable count and check if it exceeds the threshold
            _unavailableCount[id] = ++unavailableCount;

            if (unavailableCount >= slashThreshold) {
              bool slashed = slashIndicator.slashRandomBeacon(id, lastUpdatedPeriod);
              // Delete the count if the validator has been slashed
              if (slashed) delete _unavailableCount[id];
            }
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
    address sender = msg.sender;
    ValidatorType validatorType;

    for (uint256 i; i < length; ++i) {
      validatorType = validatorTypes[i];
      threshold = thresholds[i];

      _validatorThreshold[validatorType] = threshold;

      emit ValidatorThresholdUpdated(sender, validatorType, threshold);
    }
  }

  /**
   * @dev Filters out the newly joined validators based on the provided threshold.
   * @param validator The address of the validator.
   * @param currentPeriod The current period.
   * @return validCids An array of valid candidate IDs.
   */
  function _filterOutNewlyJoinedValidators(
    address validator,
    uint256 currentPeriod
  ) internal view returns (address[] memory validCids) {
    unchecked {
      uint256 count;
      uint256 threshold = COOLDOWN_PERIOD_THRESHOLD;
      address[] memory allCids = ICandidateManager(validator).getValidatorCandidateIds();
      uint256[] memory registeredAts = IProfile(getContract(ContractType.PROFILE)).getManyId2RegisteredAt(allCids);
      uint256 length = allCids.length;
      validCids = new address[](length);

      for (uint256 i; i < length; ++i) {
        if (currentPeriod - _toPeriod(registeredAts[i]) >= threshold) {
          validCids[count++] = allCids[i];
        }
      }

      assembly {
        mstore(validCids, count)
      }
    }
  }

  /**
   * @dev Checks if a given validator has submitted the random at given period.
   * @param $beacon The storage reference to the Beacon struct.
   * @param cid The candidate id to check.
   * @return true if the validator has submitted the random seed, otherwise false.
   */
  function _isSubmitted(Beacon storage $beacon, address cid) internal view returns (bool) {
    return $beacon.submitted[cid];
  }

  /**
   * @dev See {TimingStorage-_computePeriod}.
   */
  function _toPeriod(uint256 timestamp) internal view returns (uint256) {
    return timestamp / PERIOD_DURATION;
  }
}
