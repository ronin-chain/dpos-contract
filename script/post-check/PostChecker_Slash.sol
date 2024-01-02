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
import { ISlashIndicator } from "@ronin/contracts/interfaces/slash-indicator/ISlashIndicator.sol";
import { ICreditScore } from "@ronin/contracts/interfaces/slash-indicator/ICreditScore.sol";
import { ICandidateManager } from "@ronin/contracts/interfaces/validator/ICandidateManager.sol";
import { RoninValidatorSet } from "@ronin/contracts/ronin/validator/RoninValidatorSet.sol";

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

  function _postCheckSlashUnavailability() private logFn("Post check slash unavailability") {
    assertTrue(RoninValidatorSet(_validatorSet).isBlockProducer(_slashee));

    vm.coinbase(_slasher);
    vm.startPrank(_slasher);
    for (uint i; i < _tier2Threshold; i++) {
      ISlashIndicator(_slashingContract).slashUnavailability(_slashee);
      vm.roll(block.number + 1);
    }
    vm.stopPrank();

    _fastForwardToNextEpoch();
    _wrapUpEpoch();
    assertFalse(RoninValidatorSet(_validatorSet).isBlockProducer(_slashee));
    console.log(">", StdStyle.green("Post check Slashing `slashUnavailability` successful"));
  }

  function _postCheckBailOut() private logFn("Post check bail out") {
    vm.startPrank(_slasheeAdmin);

    // vm.expectEmit(_slashingContract, true, false, false, false);
    // emit BailedOut(_slashee, 0, 0);
    uint creditScoreBefore = ISlashIndicator(_slashingContract).getCreditScore(_slashee);
    ISlashIndicator(_slashingContract).bailOut(_slashee);

    uint creditScoreAfter = ISlashIndicator(_slashingContract).getCreditScore(_slashee);
    assertTrue(creditScoreBefore > creditScoreAfter);

    assertFalse(RoninValidatorSet(_validatorSet).isBlockProducer(_slashee));

    _fastForwardToNextEpoch();
    _wrapUpEpoch();
    assertTrue(RoninValidatorSet(_validatorSet).isBlockProducer(_slashee));

    console.log(">", StdStyle.green("Post check Slashing `bailOut` successful"));
  }

  function _postCheckSlashTier2AndBailOutAgain() private logFn("Post check slash tier 2 and bail out again") {
    _postCheckSlashUnavailability();

    vm.startPrank(_slasheeAdmin);
    (bool success, ) = _slashingContract.call(abi.encodeWithSelector(ICreditScore.bailOut.selector, _slashee));
    assertFalse(success);

    console.log(">", StdStyle.green("Post check Slashing `bailOut second time` successful"));
  }

  function _postCheckSlashUntilBelowRequirement() private logFn("Post check slash until below requirement") {
    ICandidateManager.ValidatorCandidate memory info = RoninValidatorSet(_validatorSet).getCandidateInfo(_slashee);
    assertTrue(info.topupDeadline == 0);
    _postCheckSlashUnavailability();

    _fastForwardToNextDay();
    _wrapUpEpoch();

    info = RoninValidatorSet(_validatorSet).getCandidateInfo(_slashee);
    assertTrue(info.topupDeadline > 0);

    console.log(">", StdStyle.green("Post check Slashing `slash until below requirement` successful"));
  }

  function _pickRandomSlashee() private {
    address[] memory consensusLst = RoninValidatorSet(_validatorSet).getValidators();
    _slashee = consensusLst[0];
    (_slasheeAdmin, , ) = IStaking(_staking).getPoolDetail(_slashee);

    _slasher = consensusLst[1];
  }

  function _pickSuitableSlasheeForSlashBelowRequirement() private {
    uint i;
    uint stakingAmount;
    uint minStakingAmount = IStaking(_staking).minValidatorStakingAmount();
    address[] memory consensusLst = RoninValidatorSet(_validatorSet).getValidators();

    do {
      _slashee = consensusLst[i];
      (_slasheeAdmin, stakingAmount, ) = IStaking(_staking).getPoolDetail(_slashee);
      i++;
    } while (stakingAmount > _slashAmountTier2 + minStakingAmount && i < consensusLst.length);

    assertTrue(i < consensusLst.length, "PostChecker_Slash: cannot find suitable validator, skip");
    _slasher = consensusLst[(i * (consensusLst.length - 1)) % consensusLst.length];
  }
}
