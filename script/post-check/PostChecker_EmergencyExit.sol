// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StdStyle } from "forge-std/StdStyle.sol";
import { console2 as console } from "forge-std/console2.sol";

import { LibErrorHandler } from "contract-libs/LibErrorHandler.sol";
import { TContract } from "foundry-deployment-kit/types/Types.sol";
import { LibProxy } from "foundry-deployment-kit/libraries/LibProxy.sol";
import { BaseMigration } from "foundry-deployment-kit/BaseMigration.s.sol";
import { Contract } from "../utils/Contract.sol";

import { ICandidateManager } from "@ronin/contracts/interfaces/validator/ICandidateManager.sol";
import { ICandidateStaking } from "@ronin/contracts/interfaces/staking/ICandidateStaking.sol";
import { IStaking } from "@ronin/contracts/interfaces/staking/IStaking.sol";
import { RoninValidatorSet } from "@ronin/contracts/ronin/validator/RoninValidatorSet.sol";

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
    _staking = CONFIG.getAddressFromCurrentNetwork(Contract.Staking.key());
    _validatorSet = CONFIG.getAddressFromCurrentNetwork(Contract.RoninValidatorSet.key());
    _candidateAdmin = makeAddr("mock-candidate-admin-to-emergency-exit");
    _consensusAddr = makeAddr("mock-consensus-addr-to-emergency-exit");

    _applyValidatorCandidate(_staking, _candidateAdmin, _consensusAddr);
    (, bytes memory returndata) =
      _validatorSet.staticcall(abi.encodeWithSelector(ICandidateManager.isValidatorCandidate.selector, _consensusAddr));
    assertTrue(abi.decode(returndata, (bool)));

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

    bytes memory returndata;
    if (IStaking(_staking).waitingSecsToRevoke() > 1 days) {
      _fastForwardToNextDay();
      _wrapUpEpoch();

      // The exited candidate still in candidate list until the time of being revoked.
      (, returndata) = _validatorSet.staticcall(
        abi.encodeWithSelector(ICandidateManager.isValidatorCandidate.selector, _consensusAddr)
      );
      assertTrue(abi.decode(returndata, (bool)));
    }

    vm.warp(block.timestamp + IStaking(_staking).waitingSecsToRevoke());
    _fastForwardToNextDay();
    _wrapUpEpoch();
    (, returndata) =
      _validatorSet.staticcall(abi.encodeWithSelector(ICandidateManager.isValidatorCandidate.selector, _consensusAddr));
    assertFalse(abi.decode(returndata, (bool)));
  }
}
