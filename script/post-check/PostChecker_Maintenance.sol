// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StdStyle } from "forge-std/StdStyle.sol";
import { console2 as console } from "forge-std/console2.sol";

import { LibErrorHandler } from "contract-libs/LibErrorHandler.sol";
import { TContract } from "foundry-deployment-kit/types/Types.sol";
import { LibProxy } from "foundry-deployment-kit/libraries/LibProxy.sol";
import { LibSharedAddress } from "foundry-deployment-kit/libraries/LibSharedAddress.sol";
import { BaseMigration } from "foundry-deployment-kit/BaseMigration.s.sol";
import { Contract } from "../utils/Contract.sol";

import { ICandidateStaking } from "@ronin/contracts/interfaces/staking/ICandidateStaking.sol";
import { IDelegatorStaking } from "@ronin/contracts/interfaces/staking/IDelegatorStaking.sol";
import { ICandidateManager } from "@ronin/contracts/interfaces/validator/ICandidateManager.sol";
import { IValidatorInfoV2 } from "@ronin/contracts/interfaces/validator/info-fragments/IValidatorInfoV2.sol";
import { RoninValidatorSet } from "@ronin/contracts/ronin/validator/RoninValidatorSet.sol";
import { IMaintenance } from "@ronin/contracts/interfaces/IMaintenance.sol";

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
    _validatorSet = CONFIG.getAddressFromCurrentNetwork(Contract.RoninValidatorSet.key());
    _staking = CONFIG.getAddressFromCurrentNetwork(Contract.Staking.key());
    _maintenance = CONFIG.getAddressFromCurrentNetwork(Contract.Maintenance.key());

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

    uint256 latestEpochBlock = RoninValidatorSet(_validatorSet).getLastUpdatedBlock();
    uint256 minOffset = IMaintenance(_maintenance).minOffsetToStartSchedule();
    uint256 numberOfBlocksInEpoch = RoninValidatorSet(_validatorSet).numberOfBlocksInEpoch();
    uint256 minDuration = IMaintenance(_maintenance).minMaintenanceDurationInBlock();

    uint startBlock = latestEpochBlock + numberOfBlocksInEpoch + 1 + minOffset;
    uint endBlock = latestEpochBlock + numberOfBlocksInEpoch + minOffset
      + numberOfBlocksInEpoch * (minDuration / numberOfBlocksInEpoch + 1);
    (bool success,) =
      _maintenance.call(abi.encodeWithSelector(IMaintenance.schedule.selector, _consensusAddr, startBlock, endBlock));
    assertEq(success, true);

    vm.stopPrank();

    bytes4 checkMaintained_Selector = IMaintenance.checkMaintained.selector;
    bytes memory res;
    (, res) = _maintenance.staticcall(abi.encodeWithSelector(checkMaintained_Selector, _consensusAddr, startBlock - 1));
    assertFalse(abi.decode(res, (bool)));

    (, res) = _maintenance.staticcall(abi.encodeWithSelector(checkMaintained_Selector, _consensusAddr, startBlock));
    assertTrue(abi.decode(res, (bool)));

    (, res) = _maintenance.staticcall(abi.encodeWithSelector(checkMaintained_Selector, _consensusAddr, startBlock + 1));
    assertTrue(abi.decode(res, (bool)));

    (, res) = _maintenance.staticcall(abi.encodeWithSelector(checkMaintained_Selector, _consensusAddr, endBlock - 1));
    assertTrue(abi.decode(res, (bool)));

    (, res) = _maintenance.staticcall(abi.encodeWithSelector(checkMaintained_Selector, _consensusAddr, endBlock));
    assertTrue(abi.decode(res, (bool)));

    (, res) = _maintenance.staticcall(abi.encodeWithSelector(checkMaintained_Selector, _consensusAddr, endBlock + 1));
    assertFalse(abi.decode(res, (bool)));
  }
}
