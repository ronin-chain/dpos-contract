// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibErrorHandler } from "contract-libs/LibErrorHandler.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { BaseMigration } from "@fdk/BaseMigration.s.sol";
import { Contract } from "../utils/Contract.sol";

import { IStaking } from "@ronin/contracts/interfaces/staking/IStaking.sol";
import { IBaseStaking } from "@ronin/contracts/interfaces/staking/IBaseStaking.sol";
import { ISlashIndicator } from "@ronin/contracts/interfaces/slash-indicator/ISlashIndicator.sol";
import { ISlashUnavailability } from "@ronin/contracts/interfaces/slash-indicator/ISlashUnavailability.sol";
import { ICreditScore } from "@ronin/contracts/interfaces/slash-indicator/ICreditScore.sol";
import { ICandidateManager } from "@ronin/contracts/interfaces/validator/ICandidateManager.sol";
import { IValidatorInfoV2 } from "@ronin/contracts/interfaces/validator/info-fragments/IValidatorInfoV2.sol";
import { LibWrapUpEpoch } from "script/shared/libraries/LibWrapUpEpoch.sol";
import "./PostChecker_Helper.sol";

abstract contract PostChecker_Slash is BaseMigration, PostChecker_Helper {
  event BailedOut(address indexed validator, uint256 period, uint256 usedCreditScore);

  using LibProxy for *;
  using LibErrorHandler for bool;

  address payable private _validatorSet;
  address private _staking;
  address private _slashingContract;
  address private _slashee;
  address private _slasheeAdmin;
  address private _slasher;

  uint256 private _tier2Threshold;
  uint256 private _slashAmountTier2;

  function _postCheck__Slash() internal {
    _validatorSet = loadContract(Contract.RoninValidatorSet.key());
    _staking = loadContract(Contract.Staking.key());
    _slashingContract = loadContract(Contract.SlashIndicator.key());
    _postCheck_RandomQueryData();

    (, _tier2Threshold, _slashAmountTier2,) = ISlashIndicator(_slashingContract).getUnavailabilitySlashingConfigs();

    uint256 snapshotId = vm.snapshot();

    _postCheck_CreditScore();
    _pickRandomSlashee();
    _postCheckSlashUnavailability();
    _postCheckBailOut();
    _postCheckSlashTier2AndBailOutAgain();

    vm.revertTo(snapshotId);
    // _pickSuitableSlasheeForSlashBelowRequirement();
    // _postCheckSlashUntilBelowRequirement();
  }

  function _postCheck_CreditScore() private {
    (uint256 gainCreditScore, uint256 maxCreditScore,,) = ICreditScore(_slashingContract).getCreditScoreConfigs();
    uint256 wrapUpCount = maxCreditScore / gainCreditScore;
    LibWrapUpEpoch.wrapUpPeriods(wrapUpCount);
  }

  function _postCheck_RandomQueryData() private logPostCheck("[Slash] query random data") {
    (uint256 tier1Threshold, uint256 tier2Threshold, uint256 slashAmountTier2, uint256 jailDuration) =
      ISlashIndicator(_slashingContract).getUnavailabilitySlashingConfigs();
    require(tier1Threshold < NORMAL_SMALL_NUMBER || tier1Threshold == 0, "abnormal tier 1");
    require(tier2Threshold < NORMAL_SMALL_NUMBER || tier2Threshold == 0, "abnormal tier 2");
    require(slashAmountTier2 >= 1 ether, "abnormal slash amount tier 2");
    require(jailDuration < NORMAL_BLOCK_NUMBER || jailDuration == 0, "abnormal jail duration");
  }

  function _postCheckSlashUnavailability() private logPostCheck("[Slash] slash unavailability tier-2") {
    bytes memory res;
    (, res) = _validatorSet.staticcall(abi.encodeWithSelector(IValidatorInfoV2.isBlockProducer.selector, _slashee));
    assertTrue(abi.decode(res, (bool)));

    vm.coinbase(_slasher);
    vm.startPrank(_slasher);
    for (uint256 i; i < _tier2Threshold; i++) {
      (bool success,) =
        _slashingContract.call(abi.encodeWithSelector(ISlashUnavailability.slashUnavailability.selector, _slashee));
      assertTrue(success);
      vm.roll(vm.getBlockNumber() + 1);
    }
    vm.stopPrank();

    LibWrapUpEpoch.wrapUpEpoch();
    (, res) = _validatorSet.staticcall(abi.encodeWithSelector(IValidatorInfoV2.isBlockProducer.selector, _slashee));
    assertFalse(abi.decode(res, (bool)));
  }

  function _postCheckBailOut() private logPostCheck("[Slash] bail out after slashed") {
    vm.startPrank(_slasheeAdmin);

    bytes memory res;
    (, res) = _slashingContract.staticcall(abi.encodeWithSelector(ICreditScore.getCreditScore.selector, _slashee));
    uint256 creditScoreBefore = abi.decode(res, (uint256));

    (bool success,) = _slashingContract.call(abi.encodeWithSelector(ICreditScore.bailOut.selector, _slashee));
    assertEq(success, true, "[Postcheck][Bailout] Cannot bailout");

    (, res) = _slashingContract.staticcall(abi.encodeWithSelector(ICreditScore.getCreditScore.selector, _slashee));
    uint256 creditScoreAfter = abi.decode(res, (uint256));
    assertTrue(creditScoreBefore > creditScoreAfter);

    (, res) = _validatorSet.staticcall(abi.encodeWithSelector(IValidatorInfoV2.isBlockProducer.selector, _slashee));
    assertFalse(abi.decode(res, (bool)));

    vm.stopPrank();

    LibWrapUpEpoch.wrapUpEpoch();
    (, res) = _validatorSet.staticcall(abi.encodeWithSelector(IValidatorInfoV2.isBlockProducer.selector, _slashee));
    assertTrue(abi.decode(res, (bool)));
  }

  function _postCheckSlashTier2AndBailOutAgain() private logPostCheck("[Slash] slashed tier 2 and bail out again") {
    _postCheckSlashUnavailability();

    vm.startPrank(_slasheeAdmin);
    (bool success,) = _slashingContract.call(abi.encodeWithSelector(ICreditScore.bailOut.selector, _slashee));
    assertFalse(success);
    vm.stopPrank();
  }

  function _postCheckSlashUntilBelowRequirement() private logPostCheck("[Slash] slash until below requirement") {
    (, bytes memory returnData) =
      _validatorSet.staticcall(abi.encodeWithSelector(ICandidateManager.getCandidateInfo.selector, _slashee));
    ICandidateManager.ValidatorCandidate memory info = abi.decode(returnData, (ICandidateManager.ValidatorCandidate));
    assertTrue(info.topupDeadline == 0);

    _postCheckSlashUnavailability();

    LibWrapUpEpoch.wrapUpPeriod();

    (, returnData) =
      _validatorSet.staticcall(abi.encodeWithSelector(ICandidateManager.getCandidateInfo.selector, _slashee));
    info = abi.decode(returnData, (ICandidateManager.ValidatorCandidate));
    assertTrue(info.topupDeadline > 0);
  }

  function _pickRandomSlashee() private {
    (, bytes memory returnedData) =
      _validatorSet.staticcall(abi.encodeWithSelector(IValidatorInfoV2.getValidators.selector));
    address[] memory consensusLst = abi.decode(returnedData, (address[]));
    _slashee = consensusLst[0];

    (, returnedData) = _staking.staticcall(abi.encodeWithSelector(IBaseStaking.getPoolDetail.selector, _slashee));
    (_slasheeAdmin,,) = abi.decode(returnedData, (address, uint256, uint256));

    _slasher = consensusLst[1];
  }

  function _pickSuitableSlasheeForSlashBelowRequirement() private {
    uint256 i;
    uint256 stakingAmount;

    uint256 minStakingAmount = IStaking(_staking).minValidatorStakingAmount();

    (, bytes memory returnedData) =
      _validatorSet.staticcall(abi.encodeWithSelector(IValidatorInfoV2.getValidators.selector));
    address[] memory consensusLst = abi.decode(returnedData, (address[]));

    do {
      _slashee = consensusLst[i];
      (, returnedData) = _staking.staticcall(abi.encodeWithSelector(IBaseStaking.getPoolDetail.selector, _slashee));
      (_slasheeAdmin, stakingAmount,) = abi.decode(returnedData, (address, uint256, uint256));

      i++;
    } while (stakingAmount >= _slashAmountTier2 + minStakingAmount && i < consensusLst.length);

    assertTrue(i < consensusLst.length, "PostChecker_Slash: cannot find suitable validator, skip");
    _slasher = consensusLst[(i * (consensusLst.length - 1)) % consensusLst.length];
  }
}
