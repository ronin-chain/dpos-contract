// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Contract } from "../utils/Contract.sol";
import { BaseMigration } from "@fdk/BaseMigration.s.sol";
import { LibErrorHandler } from "@fdk/libraries/LibErrorHandler.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";

import { IMaintenance } from "src/interfaces/IMaintenance.sol";
import { ICandidateManager } from "src/interfaces/validator/ICandidateManager.sol";
import { IRoninValidatorSet } from "src/interfaces/validator/IRoninValidatorSet.sol";
import { IValidatorInfoV2 } from "src/interfaces/validator/info-fragments/IValidatorInfoV2.sol";

import "./PostChecker_Helper.sol";

abstract contract PostChecker_Maintenance is BaseMigration, PostChecker_Helper {
  using LibProxy for *;
  using LibErrorHandler for bool;

  address payable private _validatorSet;
  address private _staking;
  address private _maintenance;
  address private _consensusAddr;
  address private _candidateAdmin;
  address payable private _delegator;

  uint256 private _delegatingValue;

  function _postCheck__Maintenance() internal {
    _validatorSet = loadContract(Contract.RoninValidatorSet.key());
    _staking = loadContract(Contract.Staking.key());
    _maintenance = loadContract(Contract.Maintenance.key());

    {
      (, bytes memory returnedData) =
        _validatorSet.staticcall(abi.encodeWithSelector(IValidatorInfoV2.getValidators.selector));
      address[] memory consensusList_AddrArrCasted = abi.decode(returnedData, (address[]));
      _consensusAddr = consensusList_AddrArrCasted[0];
    }

    {
      (, bytes memory returnedData) =
        _validatorSet.staticcall(abi.encodeWithSelector(ICandidateManager.getCandidateInfo.selector, _consensusAddr));
      uint256[7] memory candidateInfo_UintArrCasted = abi.decode(returnedData, (uint256[7]));
      _candidateAdmin = address(uint160(candidateInfo_UintArrCasted[0]));
    }

    _postCheck_scheduleMaintenance();
  }

  function _postCheck_scheduleMaintenance() private logPostCheck("[Maintenance] full flow of on schedule") {
    vm.startPrank(_candidateAdmin);

    uint256 latestEpochBlock = IRoninValidatorSet(_validatorSet).getLastUpdatedBlock();
    uint256 minOffset = IMaintenance(_maintenance).minOffsetToStartSchedule();
    uint256 numberOfBlocksInEpoch = IRoninValidatorSet(_validatorSet).numberOfBlocksInEpoch();
    uint256 minDuration = IMaintenance(_maintenance).minMaintenanceDurationInBlock();

    uint256 startBlock = latestEpochBlock + numberOfBlocksInEpoch + 1
      + ((minOffset + numberOfBlocksInEpoch) / numberOfBlocksInEpoch) * numberOfBlocksInEpoch;
    uint256 endBlock = startBlock - 1 + numberOfBlocksInEpoch * (minDuration / numberOfBlocksInEpoch + 1);
    (bool success,) =
      _maintenance.call(abi.encodeWithSelector(IMaintenance.schedule.selector, _consensusAddr, startBlock, endBlock));
    assertEq(success, true, "schedule failed");

    vm.stopPrank();

    bytes4 checkMaintained_Selector = IMaintenance.checkMaintained.selector;
    bytes memory res;
    (, res) = _maintenance.staticcall(abi.encodeWithSelector(checkMaintained_Selector, _consensusAddr, startBlock - 1));
    assertFalse(abi.decode(res, (bool)), "should not be maintained");

    (, res) = _maintenance.staticcall(abi.encodeWithSelector(checkMaintained_Selector, _consensusAddr, startBlock));
    assertTrue(abi.decode(res, (bool)), "should be maintained");

    (, res) = _maintenance.staticcall(abi.encodeWithSelector(checkMaintained_Selector, _consensusAddr, startBlock + 1));
    assertTrue(abi.decode(res, (bool)), "should be maintained at startBlock + 1");

    (, res) = _maintenance.staticcall(abi.encodeWithSelector(checkMaintained_Selector, _consensusAddr, endBlock - 1));
    assertTrue(abi.decode(res, (bool)), "should be maintained until endBlock - 1");

    (, res) = _maintenance.staticcall(abi.encodeWithSelector(checkMaintained_Selector, _consensusAddr, endBlock));
    assertTrue(abi.decode(res, (bool)), "should be maintained until endBlock");

    (, res) = _maintenance.staticcall(abi.encodeWithSelector(checkMaintained_Selector, _consensusAddr, endBlock + 1));
    assertFalse(abi.decode(res, (bool)), "should not be maintained after endBlock");
  }
}
