// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { IFastFinalityTracking } from "../../interfaces/IFastFinalityTracking.sol";
import { IMaintenance } from "../../interfaces/IMaintenance.sol";
import { IProfile } from "../../interfaces/IProfile.sol";

import { IRoninTrustedOrganization } from "../../interfaces/IRoninTrustedOrganization.sol";
import { IStakingVesting } from "../../interfaces/IStakingVesting.sol";
import { IRandomBeacon } from "../../interfaces/random-beacon/IRandomBeacon.sol";
import { ISlashIndicator } from "../../interfaces/slash-indicator/ISlashIndicator.sol";
import { IStaking } from "../../interfaces/staking/IStaking.sol";
import { ICoinbaseExecution } from "../../interfaces/validator/ICoinbaseExecution.sol";

import { LibArray } from "../../libraries/LibArray.sol";
import { Math } from "../../libraries/Math.sol";

import { TConsensus } from "../../udvts/Types.sol";
import { ErrCallerMustBeCoinbase } from "../../utils/CommonErrors.sol";
import { ContractType } from "../../utils/ContractType.sol";
import { CoinbaseExecutionDependant } from "./CoinbaseExecutionDependant.sol";
import { EmergencyExit } from "./EmergencyExit.sol";

abstract contract CoinbaseExecution is ICoinbaseExecution, CoinbaseExecutionDependant {
  using LibArray for uint256[];

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
    // TODO: remove this line in the next upgrade
    if (_firstTrackedPeriodEnd == 0) {
      _firstTrackedPeriodEnd = _lastUpdatedPeriod;
    }
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
    (uint256 validatorMiningReward, uint256 delegatorMiningReward) =
      _calcCommissionReward({ vId: id, totalReward: rewardProducingBlock });

    _validatorMiningReward[id] += validatorMiningReward;
    _delegatorMiningReward[id] += delegatorMiningReward;
  }

  /**
   * @inheritdoc ICoinbaseExecution
   */
  function onL2BlockRewardSubmitted(
    address cid
  ) external payable onlyContract(ContractType.ZK_FEE_PLAZA) {
    (uint256 validatorL2Fee, uint256 delegatorL2Fee) = _calcCommissionReward(cid, msg.value);

    _validatorL2MiningReward[cid] += validatorL2Fee;
    _delegatorL2MiningReward[cid] += delegatorL2Fee;

    emit L2BlockRewardSubmitted(cid, msg.value);
  }

  /**
   * @inheritdoc ICoinbaseExecution
   */
  function wrapUpEpoch() external payable virtual override onlyCoinbase whenEpochEnding oncePerEpoch {
    unchecked {
      uint256 newPeriod = _computePeriod(block.timestamp);
      bool periodEnding = _isPeriodEnding(newPeriod);

      uint256 lastPeriod = currentPeriod();
      uint256 epoch = epochOf(block.number);
      uint256 nextEpoch = epoch + 1;

      IRandomBeacon randomBeacon = IRandomBeacon(getContract(ContractType.RANDOM_BEACON));
      // This request is actually only invoked at the first epoch of the period.
      randomBeacon.execRequestRandomSeedForNextPeriod(lastPeriod, newPeriod);

      // Get all candidate ids
      address[] memory allCids = _candidateIds;

      _syncFastFinalityReward({ epoch: epoch, validatorIds: allCids });

      if (periodEnding) {
        ISlashIndicator slashIndicatorContract = ISlashIndicator(getContract(ContractType.SLASH_INDICATOR));
        // Slash submit random beacon proof unavailability first, then update credit scores.
        randomBeacon.execRecordAndSlashUnavailability(lastPeriod, newPeriod, address(slashIndicatorContract), allCids);
        slashIndicatorContract.execUpdateCreditScores(allCids, lastPeriod);

        (
          uint256[] memory delegatorBlockMiningRewards,
          uint256[] memory delegatorL2BlockMiningRewards,
          uint256[] memory delegatorFastFinalityRewards
        ) = _distributeRewardToTreasuriesAndCalculateTotalDelegatorsReward(lastPeriod, allCids);
        _settleAndTransferDelegatingRewards(
          lastPeriod, allCids, delegatorBlockMiningRewards, delegatorL2BlockMiningRewards, delegatorFastFinalityRewards
        );
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
        randomBeacon.execFinalizeBeaconAndPendingCids(lastPeriod, newPeriod, allCids);

        _periodEndBlock[lastPeriod] = block.number;
        _currentPeriodStartAtBlock = block.number + 1;
      }

      // Clear the previous validator set and block producer set before sync the new set from beacon.
      _clearPreviousValidatorSetAndBlockProducerSet();
      // Query the new validator set for upcoming epoch from the random beacon contract.
      // Save new set into the contract storage.
      address[] memory newValidatorIds = _syncValidatorSet(randomBeacon, newPeriod, nextEpoch);
      // Activate applicable validators into the block producer set.
      _updateApplicableValidatorToBlockProducerSet(newPeriod, nextEpoch, newValidatorIds);

      emit WrappedUpEpoch(lastPeriod, epoch, periodEnding);

      _periodOf[nextEpoch] = newPeriod;
      _lastUpdatedPeriod = newPeriod;
    }
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

    if (divisor == 0) {
      emit ZeroSumFastFinalityScore(epoch, validatorIds);
      return;
    }

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
   * @dev This loops over all validator candidates to:
   * - Update delegator reward for and calculate total delegator rewards to be sent to the staking contract,
   * - Distribute the reward of block producers and bridge operators to their treasury addresses,
   * - Update the total deprecated reward if the two previous conditions do not satisfy.
   *
   * Note: This method should be called once in the end of each period.
   *
   */
  function _distributeRewardToTreasuriesAndCalculateTotalDelegatorsReward(
    uint256 lastPeriod,
    address[] memory cids
  )
    private
    returns (
      uint256[] memory delegatorBlockMiningRewards,
      uint256[] memory delegatorL2BlockMiningRewards,
      uint256[] memory delegatorFastFinalityRewards
    )
  {
    address vId; // validator id
    address payable treasury;

    uint256 length = cids.length;
    delegatorBlockMiningRewards = new uint256[](length);
    delegatorL2BlockMiningRewards = new uint256[](length);
    delegatorFastFinalityRewards = new uint256[](length);

    (uint256 minRate, uint256 maxRate) = IStaking(getContract(ContractType.STAKING)).getCommissionRateRange();

    for (uint256 i; i < length; ++i) {
      vId = cids[i];
      treasury = _candidateInfo[vId].__shadowedTreasury;

      // Distribute the L2 mining reward to the treasury address of the validator regardless of the jail status.
      delegatorL2BlockMiningRewards[i] = _delegatorL2MiningReward[vId];
      _distributeL2MiningReward(vId, treasury);

      if (!_isJailedById(vId) && !_miningRewardDeprecatedById(vId, lastPeriod)) {
        (uint256 validatorFFReward, uint256 delegatorFFReward) = _calcCommissionReward({
          vId: vId,
          totalReward: _fastFinalityReward[vId],
          maxCommissionRate: maxRate,
          minCommissionRate: minRate
        });

        delegatorBlockMiningRewards[i] = _delegatorMiningReward[vId];
        delegatorFastFinalityRewards[i] = delegatorFFReward;

        _distributeMiningReward(vId, treasury);
        _distributeFastFinalityReward(vId, treasury, validatorFFReward);
      } else {
        _totalDeprecatedReward += _validatorMiningReward[vId] + _delegatorMiningReward[vId] + _fastFinalityReward[vId];
      }

      delete _delegatorMiningReward[vId];
      delete _validatorMiningReward[vId];
      delete _fastFinalityReward[vId];
      delete _delegatorL2MiningReward[vId];
      delete _validatorL2MiningReward[vId];
    }
  }

  /**
   * @dev Distributes the L2 mining reward to the validator's treasury address.
   *
   * Emits the `MiningRewardL2Distributed` once the reward is distributed successfully.
   * Emits the `MiningRewardL2DistributionFailed` once the contract fails to distribute reward.
   *
   * Note: This method should be called once in the end of each period.
   */
  function _distributeL2MiningReward(address cid, address payable treasury) private {
    uint256 amount = _validatorL2MiningReward[cid];
    if (amount > 0) {
      if (_unsafeSendRON(treasury, amount)) {
        emit L2MiningRewardDistributed(cid, treasury, amount);
        return;
      }

      emit MiningRewardL2DistributionFailed(cid, treasury, amount, address(this).balance);
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
    uint256 amount = _validatorMiningReward[cid];
    if (amount > 0) {
      if (_unsafeSendRONLimitGas(treasury, amount, DEFAULT_ADDITION_GAS)) {
        emit MiningRewardDistributed(cid, treasury, amount);
        return;
      }

      emit MiningRewardDistributionFailed(cid, treasury, amount, address(this).balance);
    }
  }

  /**
   * @dev Distributes the fast finality reward to the validator.
   *
   * Note: This amount must exclude the fast finality reward for delegators.
   */
  function _distributeFastFinalityReward(address cid, address payable treasury, uint256 amount) private {
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
   * Emits the `MiningRewardDelegatorsDistributed` once the block mining reward is distributed successfully.
   * Emits the `MiningRewardDelegatorsDistributionFailed` once the contract fails to distribute block mining reward.
   *
   * Emits the `FastFinalityRewardDelegatorsDistributed` once the fast finality reward is distributed successfully.
   * Emits the `FastFinalityRewardDelegatorsDistributionFailed` once the contract fails to distribute fast finality reward.
   *
   * Note: This method should be called once in the end of each period.
   * - `delegatorFFRewards` is the fast finality rewards for delegators.
   * - `delegatorMiningRewards` is the block mining rewards for delegators.
   */
  function _settleAndTransferDelegatingRewards(
    uint256 period,
    address[] memory cids,
    uint256[] memory delegatorMiningRewards,
    uint256[] memory delegatorL2MiningRewards,
    uint256[] memory delegatorFFRewards
  ) private {
    IStaking staking = IStaking(getContract(ContractType.STAKING));
    (uint256[] memory totalRewards, uint256 sumReward) =
      LibArray.addAndSum(delegatorMiningRewards, delegatorL2MiningRewards, delegatorFFRewards);

    if (sumReward != 0) {
      if (_unsafeSendRON(payable(address(staking)), sumReward)) {
        staking.execRecordRewards({ poolIds: cids, rewards: totalRewards, period: period });

        emit FastFinalityRewardDelegatorsDistributed(cids, delegatorFFRewards);
        emit MiningRewardDelegatorsDistributed(cids, delegatorMiningRewards);
        emit L2MiningRewardDelegatorsDistributed(cids, delegatorL2MiningRewards);

        return;
      }

      uint256 selfBalance = address(this).balance;
      emit FastFinalityRewardDelegatorsDistributionFailed(cids, delegatorFFRewards, selfBalance);
      emit MiningRewardDelegatorsDistributionFailed(cids, delegatorMiningRewards, selfBalance);
      emit L2MiningRewardDelegatorsDistributionFailed(cids, delegatorL2MiningRewards, selfBalance);
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
    try randomBeacon.pickValidatorSetForCurrentPeriod(nextEpoch) returns (address[] memory pickedCids) {
      newValidatorIds = pickedCids;

      // Fall back to governing validators if the new validator set is empty
      if (newValidatorIds.length == 0) {
        newValidatorIds = _fallbackToGoverningValidators(newPeriod, nextEpoch);
      }
    } catch {
      // Fall back to governing validators if the random beacon fails to pick the validator set
      newValidatorIds = _fallbackToGoverningValidators(newPeriod, nextEpoch);
    }

    _updateNewValidatorSet(newValidatorIds, newPeriod, nextEpoch);
  }

  /**
   * @dev Fallback to governing validators if the random beacon fails to pick the validator set.
   *
   * Emits the `EmptyValidatorSet` event.
   *
   */
  function _fallbackToGoverningValidators(
    uint256 newPeriod,
    uint256 nextEpoch
  ) private returns (address[] memory allGVs) {
    // TODO(TuDo1403): should add a method to query all cids of governor in Trusted Org contract
    IProfile profile = IProfile(getContract(ContractType.PROFILE));
    IRoninTrustedOrganization trustedOrg =
      IRoninTrustedOrganization(getContract(ContractType.RONIN_TRUSTED_ORGANIZATION));

    IRoninTrustedOrganization.TrustedOrganization[] memory allTrustedOrgs = trustedOrg.getAllTrustedOrganizations();
    uint256 length = allTrustedOrgs.length;
    allGVs = new address[](length);

    for (uint256 i; i < length; ++i) {
      allGVs[i] = profile.getConsensus2Id(allTrustedOrgs[i].consensusAddr);
    }

    emit EmptyValidatorSet(newPeriod, nextEpoch, allGVs);
  }

  /**
   * @dev Removes the previous validator set and block producer set.
   * This method is called at the end of each epoch.
   */
  function _clearPreviousValidatorSetAndBlockProducerSet() private {
    uint256 length = _validatorCount;

    for (uint256 i; i < length; ++i) {
      delete _validatorMap[_validatorIds[i]];
      delete _validatorIds[i];
    }

    delete _validatorCount;
  }

  /**
   * @dev Private helper function helps writing the new validator set into the contract storage.
   *
   * Emits the `ValidatorSetUpdated` event.
   *
   * Note: This method should be called once in the end of each `epoch`.
   *
   */
  function _updateNewValidatorSet(address[] memory newValidatorIds, uint256 newPeriod, uint256 nextEpoch) private {
    uint256 newValidatorCount = newValidatorIds.length;

    for (uint256 i; i < newValidatorCount; ++i) {
      _validatorIds[i] = newValidatorIds[i];
    }

    _validatorCount = newValidatorCount;

    emit ValidatorSetUpdated(newPeriod, nextEpoch, newValidatorIds);
  }

  /**
   * @dev Activate the validators from producing blocks, based on their in jail status and maintenance status.
   *
   * Requirements:
   * - This method is called at the end of each epoch
   *
   * Emits the `BlockProducerSetUpdated` event.
   *
   */
  function _updateApplicableValidatorToBlockProducerSet(
    uint256 newPeriod,
    uint256 nextEpoch,
    address[] memory newValidatorIds
  ) private {
    unchecked {
      uint256 nextBlock = block.number + 1;
      bool[] memory maintainedList =
        IMaintenance(getContract(ContractType.MAINTENANCE)).checkManyMaintainedById(newValidatorIds, nextBlock);

      // Add block producer flag for applicable validators
      uint256 length = newValidatorIds.length;

      for (uint256 i; i < length; ++i) {
        address validatorId = newValidatorIds[i];
        bool emergencyExitRequested = block.timestamp <= _emergencyExitJailedTimestamp[validatorId];
        bool isApplicable =
          !(_isJailedAtBlockById(validatorId, nextBlock) || maintainedList[i] || emergencyExitRequested);

        if (isApplicable) _validatorMap[validatorId] = true;
      }

      emit BlockProducerSetUpdated(newPeriod, nextEpoch, getBlockProducerIds());
    }
  }

  /**
   * @dev Helper function to split the reward between the validator and the delegator base on the commission rate.
   *
   * @param vId The validator id.
   * @param totalReward The total reward to be split.
   * @return validatorReward The reward for the validator.
   * @return delegatorReward The reward for the delegators.
   */
  function _calcCommissionReward(
    address vId,
    uint256 totalReward
  ) private view returns (uint256 validatorReward, uint256 delegatorReward) {
    (uint256 minRate, uint256 maxRate) = IStaking(getContract(ContractType.STAKING)).getCommissionRateRange();
    return _calcCommissionReward(vId, totalReward, minRate, maxRate);
  }

  /**
   * @dev Helper function to split the reward between the validator and the delegator base on the commission rate.
   */
  function _calcCommissionReward(
    address vId,
    uint256 totalReward,
    uint256 minCommissionRate,
    uint256 maxCommissionRate
  ) private view returns (uint256 validatorReward, uint256 delegatorReward) {
    unchecked {
      uint256 rate = Math.max(Math.min(_candidateInfo[vId].commissionRate, maxCommissionRate), minCommissionRate);

      validatorReward = (rate * totalReward) / _MAX_PERCENTAGE;
      delegatorReward = totalReward - validatorReward;
    }
  }
}
