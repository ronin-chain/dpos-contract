// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibErrorHandler } from "@fdk/libraries/LibErrorHandler.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { BaseMigration } from "@fdk/BaseMigration.s.sol";
import { Contract } from "../utils/Contract.sol";

import { ICandidateManager } from "@ronin/contracts/interfaces/validator/ICandidateManager.sol";
import { ICandidateStaking } from "@ronin/contracts/interfaces/staking/ICandidateStaking.sol";
import { IStaking } from "@ronin/contracts/interfaces/staking/IStaking.sol";
import { LibWrapUpEpoch } from "script/shared/libraries/LibWrapUpEpoch.sol";
import { LibApplyCandidate } from "script/shared/libraries/LibApplyCandidate.sol";
import "./PostChecker_Helper.sol";

abstract contract PostChecker_EmergencyExit is BaseMigration, PostChecker_Helper {
  using LibProxy for *;
  using LibErrorHandler for bool;

  address payable private _validatorSet;
  address private _staking;
  address private _consensusAddr;
  address private _candidateAdmin;
  address payable private _delegator;

  uint256 private _delegatingValue;

  function _postCheck__EmergencyExit() internal {
    _staking = loadContract(Contract.Staking.key());
    _validatorSet = loadContract(Contract.RoninValidatorSet.key());
    _candidateAdmin = makeAddr("mock-candidate-admin-to-emergency-exit");
    _consensusAddr = makeAddr("mock-consensus-addr-to-emergency-exit");

    LibApplyCandidate.applyValidatorCandidate(_staking, _candidateAdmin, _consensusAddr);
    (, bytes memory returnData) =
      _validatorSet.staticcall(abi.encodeWithSelector(ICandidateManager.isValidatorCandidate.selector, _consensusAddr));
    assertTrue(abi.decode(returnData, (bool)));

    _postCheck__RequestEmergencyExit();
  }

  function _postCheck__RequestEmergencyExit() private logPostCheck("[EmergencyExit] full flow of emergency exit") {
    vm.startPrank(_candidateAdmin);
    // Should request emergency exit success
    (bool success,) =
      _staking.call(abi.encodeWithSelector(ICandidateStaking.requestEmergencyExit.selector, _consensusAddr));
    assertTrue(success);

    // Should fail to request emergency exit again
    (success,) = _staking.call(abi.encodeWithSelector(ICandidateStaking.requestEmergencyExit.selector, _consensusAddr));
    assertFalse(success);
    vm.stopPrank();

    bytes memory returnData;
    if (IStaking(_staking).waitingSecsToRevoke() > 1 days) {
      LibWrapUpEpoch.wrapUpPeriod();

      // The exited candidate still in candidate list until the time of being revoked.
      (, returnData) = _validatorSet.staticcall(
        abi.encodeWithSelector(ICandidateManager.isValidatorCandidate.selector, _consensusAddr)
      );
      assertTrue(abi.decode(returnData, (bool)));
    }

    vm.warp(vm.getBlockTimestamp() + IStaking(_staking).waitingSecsToRevoke());
    LibWrapUpEpoch.wrapUpPeriod();
    (, returnData) =
      _validatorSet.staticcall(abi.encodeWithSelector(ICandidateManager.isValidatorCandidate.selector, _consensusAddr));
    assertFalse(abi.decode(returnData, (bool)));
  }
}
