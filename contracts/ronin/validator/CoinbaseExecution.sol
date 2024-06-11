// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/collections/HasContracts.sol";
import "../../extensions/RONTransferHelper.sol";
import "../../interfaces/IProfile.sol";
import "../../interfaces/IStakingVesting.sol";
import "../../interfaces/IMaintenance.sol";
import "../../interfaces/IFastFinalityTracking.sol";
import "../../interfaces/staking/IStaking.sol";
import "../../interfaces/IRoninTrustedOrganization.sol";
import "../../interfaces/slash-indicator/ISlashIndicator.sol";
import "../../interfaces/random-beacon/IRandomBeacon.sol";
import "../../interfaces/validator/ICoinbaseExecution.sol";
import "../../libraries/EnumFlags.sol";
import "../../libraries/Math.sol";
import { LibArray } from "../../libraries/LibArray.sol";
import {
  HasStakingVestingDeprecated,
  HasBridgeTrackingDeprecated,
  HasMaintenanceDeprecated,
  HasSlashIndicatorDeprecated
} from "../../utils/DeprecatedSlots.sol";
import "./storage-fragments/CommonStorage.sol";
import { EmergencyExit } from "./EmergencyExit.sol";
import { TPoolId } from "../../udvts/Types.sol";
import { ErrCallerMustBeCoinbase } from "../../utils/CommonErrors.sol";

abstract contract CoinbaseExecution is
  ICoinbaseExecution,
  RONTransferHelper,
  HasContracts,
  HasStakingVestingDeprecated,
  HasBridgeTrackingDeprecated,
  HasMaintenanceDeprecated,
  HasSlashIndicatorDeprecated,
  EmergencyExit
{
  using LibArray for uint256[];
  using EnumFlags for EnumFlags.ValidatorFlag;

  modifier onlyCoinbase() {
    _requireCoinbase();
    _;
  }

  modifier whenEpochEnding() {
    if (!epochEndingAt(block.number)) revert ErrAtEndOfEpochOnly();
    _;
  }

  modifier oncePerEpoch() {
    if (epochOf(_lastUpdatedBlock) >= epochOf(block.number)) revert ErrAlreadyWrappedEpoch();
    _lastUpdatedBlock = block.number;
    _;
  }

  function _requireCoinbase() private view {
    if (msg.sender != block.coinbase) revert ErrCallerMustBeCoinbase();
  }

  /**
   * @inheritdoc ICoinbaseExecution
   */
  function submitBlockReward() external payable override onlyCoinbase {
    address id = __css2cid(TConsensus.wrap(msg.sender));

    bool requestForBlockProducer =
      _isBlockProducerById(id) && !_isJailedById(id) && !_miningRewardDeprecatedById(id, currentPeriod());

    (, uint256 blockProducerBonus,, uint256 fastFinalityRewardPercentage) = IStakingVesting(
      getContract(ContractType.STAKING_VESTING)
    ).requestBonus({ forBlockProducer: requestForBlockProducer, forBridgeOperator: false });

    // Deprecates reward for non-validator or slashed validator
    if (!requestForBlockProducer) {
      _totalDeprecatedReward += msg.value;
      emit BlockRewardDeprecated(id, msg.value, BlockRewardDeprecatedType.UNAVAILABILITY);
      return;
    }

    emit BlockRewardSubmitted(id, msg.value, blockProducerBonus);

    uint256 period = currentPeriod();
    uint256 reward = msg.value + blockProducerBonus;
    uint256 rewardFastFinality = (reward * fastFinalityRewardPercentage) / _MAX_PERCENTAGE; // reward for fast finality
    uint256 rewardProducingBlock = reward - rewardFastFinality; // reward for producing blocks
    uint256 cutOffReward;

    // Add fast finality reward to total reward for current epoch, then split it later in the {wrapUpEpoch} method.
    _totalFastFinalityReward += rewardFastFinality;

    if (_miningRewardBailoutCutOffAtPeriod[msg.sender][period]) {
      (,,, uint256 cutOffPercentage) =
        ISlashIndicator(getContract(ContractType.SLASH_INDICATOR)).getCreditScoreConfigs();
      cutOffReward = (rewardProducingBlock * cutOffPercentage) / _MAX_PERCENTAGE;
      _totalDeprecatedReward += cutOffReward;
      emit BlockRewardDeprecated(id, cutOffReward, BlockRewardDeprecatedType.AFTER_BAILOUT);
    }

    rewardProducingBlock -= cutOffReward;
    (uint256 minRate, uint256 maxRate) = IStaking(getContract(ContractType.STAKING)).getCommissionRateRange();
    uint256 rate = Math.max(Math.min(_candidateInfo[id].commissionRate, maxRate), minRate);
    uint256 miningAmount = (rate * rewardProducingBlock) / _MAX_PERCENTAGE;
    _miningReward[id] += miningAmount;
    _delegatingReward[id] += (rewardProducingBlock - miningAmount);
  }

  /**
   * @inheritdoc ICoinbaseExecution
   */
  function wrapUpEpoch() external payable virtual override onlyCoinbase whenEpochEnding oncePerEpoch {
    uint256 newPeriod = _computePeriod(block.timestamp);
    bool periodEnding = _isPeriodEnding(newPeriod);

    uint256 lastPeriod = currentPeriod();
    uint256 epoch = epochOf(block.number);
    uint256 nextEpoch = epoch + 1;
    address[] memory currValidatorIds = getValidatorIds();

    IRandomBeacon randomBeacon = IRandomBeacon(getContract(ContractType.RANDOM_BEACON));
    // This request is actually only invoked at the first epoch of the period.
    randomBeacon.execRequestRandomSeedForNextPeriod(lastPeriod, newPeriod);

    _syncFastFinalityReward(epoch, currValidatorIds);

    if (periodEnding) {
      // Get all candidate ids
      address[] memory allCids = _candidateIds;

      ISlashIndicator slashIndicatorContract = ISlashIndicator(getContract(ContractType.SLASH_INDICATOR));
      // Slash submit random beacon proof unavailability first, then update credit scores.
      randomBeacon.execRecordAndSlashUnavailability(lastPeriod, newPeriod, address(slashIndicatorContract), allCids);
      slashIndicatorContract.execUpdateCreditScores(allCids, lastPeriod);

      (uint256 totalDelegatingReward, uint256[] memory delegatingRewards) =
        _distributeRewardToTreasuriesAndCalculateTotalDelegatingReward(lastPeriod, allCids);
      _settleAndTransferDelegatingRewards(lastPeriod, allCids, totalDelegatingReward, delegatingRewards);
      _tryRecycleLockedFundsFromEmergencyExits();
      _recycleDeprecatedRewards();

      address[] memory revokedCandidateIds = _syncCandidateSet(newPeriod);
      if (revokedCandidateIds.length > 0) {
        // Re-update `allCids` after unsatisfied candidates get removed.
        allCids = _candidateIds;
        slashIndicatorContract.execResetCreditScores(revokedCandidateIds);
      }

      // Wrap up the beacon period includes (1) finalizing the beacon proof, and (2) determining the validator list for the next period by new proof.
      // Should wrap up the beacon after unsatisfied candidates get removed.
      randomBeacon.execWrapUpBeaconAndPendingCids(lastPeriod, newPeriod, allCids);

      _currentPeriodStartAtBlock = block.number + 1;
    }

    currValidatorIds = _syncValidatorSet(randomBeacon, newPeriod, nextEpoch);
    _removeInapplicableAndUpdateNewBlockProducers(newPeriod, nextEpoch, currValidatorIds);

    emit WrappedUpEpoch(lastPeriod, epoch, periodEnding);

    _periodOf[nextEpoch] = newPeriod;
    _lastUpdatedPeriod = newPeriod;
  }

  /**
   * @dev This method calculate and update reward of each `validators` accordingly their fast finality voting performance
   * in the `epoch`. The leftover reward is added to the {_totalDeprecatedReward} and is recycled later to the
   * {StakingVesting} contract.
   *
   * Requirements:
   * - This method is only called once each epoch.
   */
  function _syncFastFinalityReward(uint256 epoch, address[] memory validatorIds) private {
    uint256[] memory scores = IFastFinalityTracking(getContract(ContractType.FAST_FINALITY_TRACKING))
      .getManyFinalityScoresById(epoch, validatorIds);
    uint256 divisor = scores.sum();

    if (divisor == 0) return;

    uint256 iReward;
    uint256 totalReward = _totalFastFinalityReward;
    uint256 totalDispensedReward = 0;
    uint256 length = validatorIds.length;

    for (uint256 i; i < length; ++i) {
      iReward = (totalReward * scores[i]) / divisor;
      _fastFinalityReward[validatorIds[i]] += iReward;
      totalDispensedReward += iReward;
    }

    _totalDeprecatedReward += (totalReward - totalDispensedReward);
    delete _totalFastFinalityReward;
  }

  /**
   * @dev This loops over all current validators to:
   * - Update delegating reward for and calculate total delegating rewards to be sent to the staking contract,
   * - Distribute the reward of block producers and bridge operators to their treasury addresses,
   * - Update the total deprecated reward if the two previous conditions do not satisfy.
   *
   * Note: This method should be called once in the end of each period.
   *
   */
  function _distributeRewardToTreasuriesAndCalculateTotalDelegatingReward(
    uint256 lastPeriod,
    address[] memory currValidatorIds
  ) private returns (uint256 totalDelegatingReward, uint256[] memory delegatingRewards) {
    address vId; // validator id
    address payable treasury;
    delegatingRewards = new uint256[](currValidatorIds.length);

    for (uint _i; _i < currValidatorIds.length;) {
      vId = currValidatorIds[_i];
      treasury = _candidateInfo[vId].__shadowedTreasury;

      if (!_isJailedById(vId) && !_miningRewardDeprecatedById(vId, lastPeriod)) {
        totalDelegatingReward += _delegatingReward[vId];
        delegatingRewards[_i] = _delegatingReward[vId];
        _distributeMiningReward(vId, treasury);
        _distributeFastFinalityReward(vId, treasury);
      } else {
        _totalDeprecatedReward += _miningReward[vId] + _delegatingReward[vId] + _fastFinalityReward[vId];
      }

      delete _delegatingReward[vId];
      delete _miningReward[vId];
      delete _fastFinalityReward[vId];

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @dev Distributes bonus of staking vesting and mining fee for the block producer.
   *
   * Emits the `MiningRewardDistributed` once the reward is distributed successfully.
   * Emits the `MiningRewardDistributionFailed` once the contract fails to distribute reward.
   *
   * Note: This method should be called once in the end of each period.
   *
   */
  function _distributeMiningReward(address cid, address payable treasury) private {
    uint256 amount = _miningReward[cid];
    if (amount > 0) {
      if (_unsafeSendRONLimitGas(treasury, amount, DEFAULT_ADDITION_GAS)) {
        emit MiningRewardDistributed(cid, treasury, amount);
        return;
      }

      emit MiningRewardDistributionFailed(cid, treasury, amount, address(this).balance);
    }
  }

  function _distributeFastFinalityReward(address cid, address payable treasury) private {
    uint256 amount = _fastFinalityReward[cid];
    if (amount > 0) {
      if (_unsafeSendRONLimitGas(treasury, amount, DEFAULT_ADDITION_GAS)) {
        emit FastFinalityRewardDistributed(cid, treasury, amount);
        return;
      }

      emit FastFinalityRewardDistributionFailed(cid, treasury, amount, address(this).balance);
    }
  }

  /**
   * @dev Helper function to settle rewards for delegators of `currValidatorIds` at the end of each period,
   * then transfer the rewards from this contract to the staking contract, in order to finalize a period.
   *
   * Emits the `StakingRewardDistributed` once the reward is distributed successfully.
   * Emits the `StakingRewardDistributionFailed` once the contract fails to distribute reward.
   *
   * Note: This method should be called once in the end of each period.
   *
   */
  function _settleAndTransferDelegatingRewards(
    uint256 period,
    address[] memory currValidatorIds,
    uint256 totalDelegatingReward,
    uint256[] memory delegatingRewards
  ) private {
    IStaking _staking = IStaking(getContract(ContractType.STAKING));
    if (totalDelegatingReward > 0) {
      if (_unsafeSendRON(payable(address(_staking)), totalDelegatingReward)) {
        _staking.execRecordRewards(currValidatorIds, delegatingRewards, period);
        emit StakingRewardDistributed(totalDelegatingReward, currValidatorIds, delegatingRewards);
        return;
      }

      emit StakingRewardDistributionFailed(
        totalDelegatingReward, currValidatorIds, delegatingRewards, address(this).balance
      );
    }
  }

  /**
   * @dev Transfer the deprecated rewards e.g. the rewards that get deprecated when validator is slashed/maintained,
   * to the staking vesting contract
   *
   * Note: This method should be called once in the end of each period.
   */
  function _recycleDeprecatedRewards() private {
    uint256 withdrawAmount = _totalDeprecatedReward;

    if (withdrawAmount != 0) {
      address withdrawTarget = getContract(ContractType.STAKING_VESTING);

      delete _totalDeprecatedReward;

      (bool _success,) =
        withdrawTarget.call{ value: withdrawAmount }(abi.encodeWithSelector(IStakingVesting.receiveRON.selector));

      if (_success) {
        emit DeprecatedRewardRecycled(withdrawTarget, withdrawAmount);
      } else {
        emit DeprecatedRewardRecycleFailed(withdrawTarget, withdrawAmount, address(this).balance);
      }
    }
  }

  /**
   * @dev Updates the validator set based on the validator candidates from the Staking contract.
   *
   * Emits the `ValidatorSetUpdated` event.
   *
   * Note: This method should be called once in the end of each period.
   *
   */
  function _syncValidatorSet(
    IRandomBeacon randomBeacon,
    uint256 newPeriod,
    uint256 nextEpoch
  ) private returns (address[] memory newValidatorIds) {
    newValidatorIds = randomBeacon.pickValidatorSetForCurrentPeriod(nextEpoch);

    // Fallback to all governing validators if the retrieved validator set is empty.
    if (newValidatorIds.length == 0) {
      IProfile profile = IProfile(getContract(ContractType.PROFILE));
      IRoninTrustedOrganization.TrustedOrganization[] memory allTrustedOrgs =
        IRoninTrustedOrganization(getContract(ContractType.RONIN_TRUSTED_ORGANIZATION)).getAllTrustedOrganizations();

      uint256 length = allTrustedOrgs.length;
      newValidatorIds = new address[](length);
      for (uint256 i; i < length; ++i) {
        newValidatorIds[i] = profile.getConsensus2Id(allTrustedOrgs[i].consensusAddr);
      }

      emit EmptyValidatorSet(newPeriod, nextEpoch, newValidatorIds);
    }

    _setNewValidatorSet(newValidatorIds, newPeriod, nextEpoch);
  }

  /**
   * @dev Private helper function helps writing the new validator set into the contract storage.
   *
   * Emits the `ValidatorSetUpdated` event.
   *
   * Note: This method should be called once in the end of each period.
   *
   */
  function _setNewValidatorSet(address[] memory newValidators, uint256 newPeriod, uint256 nextEpoch) private {
    uint256 newValidatorCount = newValidators.length;
    uint256 prevValidatorCount = _validatorCount;

    // Remove exceeding validators in the current set
    for (uint256 i = newValidatorCount; i < prevValidatorCount; ++i) {
      delete _validatorMap[_validatorIds[i]];
      delete _validatorIds[i];
    }

    address newValidator;
    // Update new validator set and set flag correspondingly.
    for (uint256 i; i < newValidatorCount; ++i) {
      // Remove the flag for the validator in the previous set
      delete _validatorMap[_validatorIds[i]];

      newValidator = newValidators[i];

      _validatorMap[newValidator] = EnumFlags.ValidatorFlag.Both;
      _validatorIds[i] = newValidator;
    }

    _validatorCount = newValidatorCount;

    emit ValidatorSetUpdated(newPeriod, nextEpoch, newValidators);
  }

  /**
   * @dev Activate/Deactivate the validators from producing blocks, based on their in jail status and maintenance status.
   *
   * Requirements:
   * - This method is called at the end of each epoch
   *
   * Emits the `BlockProducerSetUpdated` event.
   * Emits the `BridgeOperatorSetUpdated` event.
   *
   */
  function _removeInapplicableAndUpdateNewBlockProducers(
    uint256 newPeriod,
    uint256 nextEpoch,
    address[] memory currValidatorIds
  ) private {
    uint256 nextBlock = block.number + 1;
    bool[] memory maintainedList =
      IMaintenance(getContract(ContractType.MAINTENANCE)).checkManyMaintainedById(currValidatorIds, nextBlock);

    // Remove block producer flag for all validators in the previous set
    address[] memory prevBlockProducers = getBlockProducerIds();
    uint256 length = prevBlockProducers.length;
    for (uint256 i; i < length; ++i) {
      address prevBlockProducerId = prevBlockProducers[i];

      _validatorMap[prevBlockProducerId] =
        _validatorMap[prevBlockProducerId].removeFlag(EnumFlags.ValidatorFlag.BlockProducer);
    }

    length = currValidatorIds.length;
    for (uint256 i; i < length; ++i) {
      address validatorId = currValidatorIds[i];
      bool emergencyExitRequested = block.timestamp <= _emergencyExitJailedTimestamp[validatorId];
      bool isNotKickedAfter =
        !(_isJailedAtBlockById(validatorId, nextBlock) || maintainedList[i] || emergencyExitRequested);

      if (isNotKickedAfter) {
        _validatorMap[validatorId] = _validatorMap[validatorId].addFlag(EnumFlags.ValidatorFlag.BlockProducer);
      }
    }

    emit BlockProducerSetUpdated(newPeriod, nextEpoch, getBlockProducerIds());
  }
}
