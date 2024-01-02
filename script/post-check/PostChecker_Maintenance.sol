// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StdStyle } from "forge-std/StdStyle.sol";
import { console2 as console } from "forge-std/console2.sol";

import { LibErrorHandler } from "contract-libs/LibErrorHandler.sol";
import { TContract } from "foundry-deployment-kit/types/Types.sol";
import { LibProxy } from "foundry-deployment-kit/libraries/LibProxy.sol";
import { BaseMigration } from "foundry-deployment-kit/BaseMigration.s.sol";
import { Contract } from "../utils/Contract.sol";

import { ICandidateStaking } from "@ronin/contracts/interfaces/staking/ICandidateStaking.sol";
import { IDelegatorStaking } from "@ronin/contracts/interfaces/staking/IDelegatorStaking.sol";
import { ICandidateManager } from "@ronin/contracts/interfaces/validator/ICandidateManager.sol";
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

    _consensusAddr = RoninValidatorSet(_validatorSet).getValidators()[0];
    ICandidateManager.ValidatorCandidate memory candidateInfo = RoninValidatorSet(_validatorSet).getCandidateInfo(
      _consensusAddr
    );

    _candidateAdmin = candidateInfo.admin;

    _postCheck_scheduleMaintenance();
  }

  function _postCheck_scheduleMaintenance() private logFn("Post check schedule") {
    vm.startPrank(_candidateAdmin);

    uint latestEpochBlock = RoninValidatorSet(_validatorSet).getLastUpdatedBlock();
    uint minOffset = IMaintenance(_maintenance).minOffsetToStartSchedule();
    uint minDuration = IMaintenance(_maintenance).minMaintenanceDurationInBlock();

    uint startBlock = latestEpochBlock + 200 + 1 + minOffset;
    uint endBlock = latestEpochBlock + 200 + minOffset + minDuration;
    IMaintenance(_maintenance).schedule(_consensusAddr, startBlock, endBlock);

    vm.stopPrank();

    assertFalse(IMaintenance(_maintenance).checkMaintained(_consensusAddr, startBlock - 1));
    assertTrue(IMaintenance(_maintenance).checkMaintained(_consensusAddr, startBlock));
    assertTrue(IMaintenance(_maintenance).checkMaintained(_consensusAddr, startBlock + 1));
    assertTrue(IMaintenance(_maintenance).checkMaintained(_consensusAddr, endBlock - 1));
    assertTrue(IMaintenance(_maintenance).checkMaintained(_consensusAddr, endBlock));
    assertFalse(IMaintenance(_maintenance).checkMaintained(_consensusAddr, endBlock + 1));

    console.log(">", StdStyle.green("Post check Staking `schedule` successful"));
  }
}
