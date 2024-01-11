// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StdStyle } from "forge-std/StdStyle.sol";
import { console2 as console } from "forge-std/console2.sol";

import { LibErrorHandler } from "contract-libs/LibErrorHandler.sol";
import { TContract } from "foundry-deployment-kit/types/Types.sol";
import { LibProxy } from "foundry-deployment-kit/libraries/LibProxy.sol";
import { BaseMigration } from "foundry-deployment-kit/BaseMigration.s.sol";
import { Contract } from "../utils/Contract.sol";

import { IStaking } from "@ronin/contracts/interfaces/staking/IStaking.sol";
import { IBaseStaking } from "@ronin/contracts/interfaces/staking/IBaseStaking.sol";
import { ISlashIndicator } from "@ronin/contracts/interfaces/slash-indicator/ISlashIndicator.sol";
import { ISlashUnavailability } from "@ronin/contracts/interfaces/slash-indicator/ISlashUnavailability.sol";
import { ICreditScore } from "@ronin/contracts/interfaces/slash-indicator/ICreditScore.sol";
import { ICandidateManager } from "@ronin/contracts/interfaces/validator/ICandidateManager.sol";
import { RoninValidatorSet } from "@ronin/contracts/ronin/validator/RoninValidatorSet.sol";
import { IValidatorInfoV2 } from "@ronin/contracts/interfaces/validator/info-fragments/IValidatorInfoV2.sol";

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
    _validatorSet = CONFIG.getAddressFromCurrentNetwork(Contract.RoninValidatorSet.key());
    _staking = CONFIG.getAddressFromCurrentNetwork(Contract.Staking.key());
    _slashingContract = CONFIG.getAddressFromCurrentNetwork(Contract.SlashIndicator.key());
    _postCheck_RandomQueryData();

    (, _tier2Threshold, _slashAmountTier2, ) = ISlashIndicator(_slashingContract).getUnavailabilitySlashingConfigs();

    _pickRandomSlashee();
    uint256 snapshotId = vm.snapshot();
    _postCheckSlashUnavailability();
    _postCheckBailOut();
    _postCheckSlashTier2AndBailOutAgain();

    vm.revertTo(snapshotId);
    _pickSuitableSlasheeForSlashBelowRequirement();
    _postCheckSlashUntilBelowRequirement();
  }

  function _postCheck_RandomQueryData() private view logPostCheck("[Slash] query random data") {
    (uint tier1Threshold, uint tier2Threshold, uint slashAmountTier2, uint jailDuration) = ISlashIndicator(
      _slashingContract
    ).getUnavailabilitySlashingConfigs();
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
    for (uint i; i < _tier2Threshold; i++) {
      (bool success, ) = _slashingContract.call(
        abi.encodeWithSelector(ISlashUnavailability.slashUnavailability.selector, _slashee)
      );
      assertTrue(success);
      vm.roll(block.number + 1);
    }
    vm.stopPrank();

    _fastForwardToNextEpoch();
    _wrapUpEpoch();
    (, res) = _validatorSet.staticcall(abi.encodeWithSelector(IValidatorInfoV2.isBlockProducer.selector, _slashee));
    assertFalse(abi.decode(res, (bool)));
  }

  function _postCheckBailOut() private logPostCheck("[Slash] bail out after slashed") {
    vm.startPrank(_slasheeAdmin);

    bytes memory res;
    (, res) = _slashingContract.staticcall(abi.encodeWithSelector(ICreditScore.getCreditScore.selector, _slashee));
    uint creditScoreBefore = abi.decode(res, (uint));

    (bool success, ) = _slashingContract.call(abi.encodeWithSelector(ICreditScore.bailOut.selector, _slashee));
    assertEq(success, true);

    (, res) = _slashingContract.staticcall(abi.encodeWithSelector(ICreditScore.getCreditScore.selector, _slashee));
    uint creditScoreAfter = abi.decode(res, (uint));
    assertTrue(creditScoreBefore > creditScoreAfter);

    (, res) = _validatorSet.staticcall(abi.encodeWithSelector(IValidatorInfoV2.isBlockProducer.selector, _slashee));
    assertFalse(abi.decode(res, (bool)));

    _fastForwardToNextEpoch();
    _wrapUpEpoch();
    (, res) = _validatorSet.staticcall(abi.encodeWithSelector(IValidatorInfoV2.isBlockProducer.selector, _slashee));
    assertTrue(abi.decode(res, (bool)));
  }

  function _postCheckSlashTier2AndBailOutAgain() private logPostCheck("[Slash] slashed tier 2 and bail out again") {
    _postCheckSlashUnavailability();

    vm.startPrank(_slasheeAdmin);
    (bool success, ) = _slashingContract.call(abi.encodeWithSelector(ICreditScore.bailOut.selector, _slashee));
    assertFalse(success);
  }

  function _postCheckSlashUntilBelowRequirement() private logPostCheck("[Slash] slash until below requirement") {
    (, bytes memory returndata) = _validatorSet.staticcall(
      abi.encodeWithSelector(ICandidateManager.getCandidateInfo.selector, _slashee)
    );
    ICandidateManager.ValidatorCandidate memory info = abi.decode(returndata, (ICandidateManager.ValidatorCandidate));
    assertTrue(info.topupDeadline == 0);
    _postCheckSlashUnavailability();

    _fastForwardToNextDay();
    _wrapUpEpoch();

    (, returndata) = _validatorSet.staticcall(
      abi.encodeWithSelector(ICandidateManager.getCandidateInfo.selector, _slashee)
    );
    info = abi.decode(returndata, (ICandidateManager.ValidatorCandidate));
    assertTrue(info.topupDeadline > 0);
  }

  function _pickRandomSlashee() private {
    (, bytes memory returnedData) = _validatorSet.staticcall(
      abi.encodeWithSelector(IValidatorInfoV2.getValidators.selector)
    );
    address[] memory consensusLst = abi.decode(returnedData, (address[]));
    _slashee = consensusLst[0];

    (, returnedData) = _staking.staticcall(abi.encodeWithSelector(IBaseStaking.getPoolDetail.selector, _slashee));
    (_slasheeAdmin, , ) = abi.decode(returnedData, (address, uint, uint));

    _slasher = consensusLst[1];
  }

  function _pickSuitableSlasheeForSlashBelowRequirement() private {
    uint i;
    uint stakingAmount;

    uint minStakingAmount = IStaking(_staking).minValidatorStakingAmount();

    (, bytes memory returnedData) = _validatorSet.staticcall(
      abi.encodeWithSelector(IValidatorInfoV2.getValidators.selector)
    );
    address[] memory consensusLst = abi.decode(returnedData, (address[]));

    do {
      _slashee = consensusLst[i];
      (, returnedData) = _staking.staticcall(abi.encodeWithSelector(IBaseStaking.getPoolDetail.selector, _slashee));
      (_slasheeAdmin, stakingAmount, ) = abi.decode(returnedData, (address, uint, uint));

      i++;
    } while (stakingAmount > _slashAmountTier2 + minStakingAmount && i < consensusLst.length);

    assertTrue(i < consensusLst.length, "PostChecker_Slash: cannot find suitable validator, skip");
    _slasher = consensusLst[(i * (consensusLst.length - 1)) % consensusLst.length];
  }
}
