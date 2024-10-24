// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Contract } from "../utils/Contract.sol";
import { BaseMigration } from "@fdk/BaseMigration.s.sol";
import { LibErrorHandler } from "@fdk/libraries/LibErrorHandler.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";

import "./PostChecker_Helper.sol";
import { LibWrapUpEpoch } from "script/shared/libraries/LibWrapUpEpoch.sol";
import { ICandidateStaking } from "src/interfaces/staking/ICandidateStaking.sol";
import { IDelegatorStaking } from "src/interfaces/staking/IDelegatorStaking.sol";
import { IStaking } from "src/interfaces/staking/IStaking.sol";
import { IValidatorInfoV2 } from "src/interfaces/validator/info-fragments/IValidatorInfoV2.sol";

abstract contract PostChecker_Staking is BaseMigration, PostChecker_Helper {
  using LibProxy for *;
  using LibErrorHandler for bool;

  address payable private _validatorSet;
  address private _staking;
  address private _consensusAddr;
  address private _consensusAddr2;
  address payable private _delegator;

  uint256 private _delegatingValue;

  function _postCheck__Staking() internal {
    _validatorSet = loadContract(Contract.RoninValidatorSet.key());
    _staking = loadContract(Contract.Staking.key());

    (, bytes memory returnedData) =
      _validatorSet.staticcall(abi.encodeWithSelector(IValidatorInfoV2.getValidators.selector));
    address[] memory consensusList_AddrArrCasted = abi.decode(returnedData, (address[]));

    _consensusAddr = consensusList_AddrArrCasted[0];
    _consensusAddr2 = consensusList_AddrArrCasted[1];
    _delegator = payable(makeAddr("mock-delegator"));

    _delegatingValue = 100 ether;
    vm.deal(_delegator, _delegatingValue);

    _postCheckDelegate();
    _postCheckClaimReward();
    _postCheckUndelegate();
    _postCheckRedelegate();
  }

  function _postCheckDelegate() private logPostCheck("[Staking] delegate") {
    vm.startPrank(_delegator);
    (bool success, bytes memory returnData) = _staking.call{ value: _delegatingValue }(
      abi.encodeWithSelector(IDelegatorStaking.delegate.selector, _consensusAddr)
    );

    vm.stopPrank();
    success.handleRevert(ICandidateStaking.applyValidatorCandidate.selector, returnData);
    assertTrue(success);
  }

  function _postCheckClaimReward() private logPostCheck("[Staking] claim rewards") {
    vm.coinbase(_consensusAddr);
    LibWrapUpEpoch.wrapUpPeriod();

    address[] memory consensusList = new address[](1);
    consensusList[0] = _consensusAddr;

    vm.startPrank(_delegator);
    (bool success,) = _staking.call(abi.encodeWithSelector(IDelegatorStaking.claimRewards.selector, consensusList));
    assertEq(success, true);

    vm.stopPrank();
  }

  function _postCheckUndelegate() private logPostCheck("[Staking] undelegate") {
    LibWrapUpEpoch.wrapUpPeriods(3);

    vm.startPrank(_delegator);
    (bool success, bytes memory returnData) =
      _staking.call(abi.encodeWithSelector(IDelegatorStaking.undelegate.selector, _consensusAddr, _delegatingValue + 1));
    assertFalse(success);

    (success, returnData) =
      _staking.call(abi.encodeWithSelector(IDelegatorStaking.undelegate.selector, _consensusAddr, _delegatingValue));
    assertTrue(success);

    vm.stopPrank();
  }

  function _postCheckRedelegate() private logPostCheck("[Staking] redelegate") {
    _postCheckDelegate();
    vm.warp(vm.getBlockTimestamp() + IStaking(_staking).cooldownSecsToUndelegate() + 1);

    vm.startPrank(_delegator);
    (bool success,) = _staking.call(
      abi.encodeWithSelector(IDelegatorStaking.redelegate.selector, _consensusAddr, _consensusAddr2, _delegatingValue)
    );
    assertTrue(success);

    vm.stopPrank();
  }
}
