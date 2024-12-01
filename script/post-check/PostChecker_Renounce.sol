// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Contract } from "../utils/Contract.sol";
import { BaseMigration } from "@fdk/BaseMigration.s.sol";
import { LibErrorHandler } from "@fdk/libraries/LibErrorHandler.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";

import "./PostChecker_Helper.sol";
import { LibApplyCandidate } from "script/shared/libraries/LibApplyCandidate.sol";
import { LibWrapUpEpoch } from "script/shared/libraries/LibWrapUpEpoch.sol";
import { ICandidateStaking } from "src/interfaces/staking/ICandidateStaking.sol";
import { IStaking } from "src/interfaces/staking/IStaking.sol";
import { ICandidateManager } from "src/interfaces/validator/ICandidateManager.sol";

abstract contract PostChecker_Renounce is BaseMigration, PostChecker_Helper {
  using LibProxy for *;
  using LibErrorHandler for bool;

  address payable private _validatorSet;
  address private _staking;
  address private _consensusAddr;
  address private _candidateAdmin;
  address payable private _delegator;

  uint256 private _delegatingValue;

  function _postCheck__Renounce() internal {
    _staking = loadContract(Contract.Staking.key());
    _validatorSet = loadContract(Contract.RoninValidatorSet.key());
    _candidateAdmin = makeAddr("mock-candidate-admin-to-renounce");
    _consensusAddr = makeAddr("mock-consensus-addr-to-renounce");

    LibApplyCandidate.applyValidatorCandidate(_staking, _candidateAdmin, _consensusAddr);
    (, bytes memory returnData) =
      _validatorSet.staticcall(abi.encodeWithSelector(ICandidateManager.isValidatorCandidate.selector, _consensusAddr));
    assertTrue(abi.decode(returnData, (bool)));

    _postCheck__RequestRenounceSuccess();
  }

  function _postCheck__RequestRenounceSuccess() private logPostCheck("[Staking][Renounce] request renounce") {
    vm.startPrank(_candidateAdmin);
    (bool success,) = _staking.call(abi.encodeWithSelector(ICandidateStaking.requestRenounce.selector, _consensusAddr));
    assertTrue(success);
    vm.stopPrank();

    vm.warp(vm.getBlockTimestamp() + IStaking(_staking).waitingSecsToRevoke());
    LibWrapUpEpoch.wrapUpPeriod();
    (, bytes memory returnData) =
      _validatorSet.staticcall(abi.encodeWithSelector(ICandidateManager.isValidatorCandidate.selector, _consensusAddr));
    assertFalse(abi.decode(returnData, (bool)));
  }
}
