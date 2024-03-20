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
import { ICandidateStaking } from "@ronin/contracts/interfaces/staking/ICandidateStaking.sol";
import { IDelegatorStaking } from "@ronin/contracts/interfaces/staking/IDelegatorStaking.sol";
import { IValidatorInfoV2 } from "@ronin/contracts/interfaces/validator/info-fragments/IValidatorInfoV2.sol";
import { RoninValidatorSet } from "@ronin/contracts/ronin/validator/RoninValidatorSet.sol";

import "./PostChecker_Helper.sol";

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
    _validatorSet = CONFIG.getAddressFromCurrentNetwork(Contract.RoninValidatorSet.key());
    _staking = CONFIG.getAddressFromCurrentNetwork(Contract.Staking.key());

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
    _fastForwardToNextDay();
    _wrapUpEpoch();

    address[] memory consensusList = new address[](1);
    consensusList[0] = _consensusAddr;

    vm.startPrank(_delegator);
    (bool success,) = _staking.call(abi.encodeWithSelector(IDelegatorStaking.claimRewards.selector, consensusList));
    assertEq(success, true);

    vm.stopPrank();
  }

  function _postCheckUndelegate() private logPostCheck("[Staking] undelegate") {
    _fastForwardToNextDay();
    _fastForwardToNextDay();
    _fastForwardToNextDay();
    _wrapUpEpoch();

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
    vm.warp(block.timestamp + IStaking(_staking).cooldownSecsToUndelegate() + 1);

    vm.startPrank(_delegator);
    (bool success,) = _staking.call(
      abi.encodeWithSelector(IDelegatorStaking.redelegate.selector, _consensusAddr, _consensusAddr2, _delegatingValue)
    );
    assertTrue(success);

    vm.stopPrank();
  }
}
