// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StdStyle } from "forge-std/StdStyle.sol";
import { console2 as console } from "forge-std/console2.sol";

import { BaseMigration } from "foundry-deployment-kit/BaseMigration.s.sol";
import { LibErrorHandler } from "contract-libs/LibErrorHandler.sol";
import { Contract } from "../utils/Contract.sol";

import { ICandidateStaking } from "@ronin/contracts/interfaces/staking/ICandidateStaking.sol";
import { RoninValidatorSet } from "@ronin/contracts/ronin/validator/RoninValidatorSet.sol";

abstract contract PostChecker_Helper is BaseMigration {
  uint256 NORMAL_SMALL_NUMBER = 1_000_000;
  uint256 NORMAL_BLOCK_NUMBER = 100_000_000;

  using LibErrorHandler for bool;

  modifier logPostCheck(string memory task) {
    console.log(string.concat("[>] Post-checking: ", task, "..."));
    _;
    console.log(StdStyle.green(string.concat("    Check success: ", task, unicode"... ✅")));
  }

  function _applyValidatorCandidate(address staking, address candidateAdmin, address consensusAddr) internal {
    uint256 value = ICandidateStaking(staking).minValidatorStakingAmount();
    _applyValidatorCandidate(staking, candidateAdmin, consensusAddr, value);
  }

  function _applyValidatorCandidate(
    address staking,
    address candidateAdmin,
    address consensusAddr,
    uint256 value
  ) internal {
    vm.deal(candidateAdmin, value);
    vm.startPrank(candidateAdmin);

    // After fixed BLS REP-4 ABI
    (bool success, bytes memory returnData) = staking.call{ value: value }(
      abi.encodeWithSelector(
        ICandidateStaking.applyValidatorCandidate.selector,
        candidateAdmin,
        consensusAddr,
        candidateAdmin,
        15_00,
        bytes(string.concat("mock-pub-key", vm.toString(candidateAdmin))),
        bytes(string.concat("mock-proof-of-possession", vm.toString(candidateAdmin)))
      )
    );

    // REP-3 ABI
    if (!success) {
      (success, returnData) = staking.call{ value: value }(
        abi.encodeWithSelector(
          ICandidateStaking.applyValidatorCandidate.selector,
          candidateAdmin,
          consensusAddr,
          candidateAdmin,
          15_00,
          bytes(string.concat("mock-pub-key", vm.toString(candidateAdmin)))
        )
      );
    }

    // Before REP-3 ABI
    if (!success) {
      (success, returnData) = staking.call{ value: value }(
        abi.encodeWithSelector(
          ICandidateStaking.applyValidatorCandidate.selector,
          candidateAdmin,
          consensusAddr,
          candidateAdmin,
          15_00
        )
      );
    }
    vm.stopPrank();
    success.handleRevert(ICandidateStaking.applyValidatorCandidate.selector, returnData);
  }

  function _wrapUpEpochs(uint256 times) internal {
    for (uint256 i; i < times; ++i) {
      _fastForwardToNextDay();
      _wrapUpEpoch();
    }
  }

  function _wrapUpEpoch() internal {
    _wrapUpEpoch(block.coinbase);
  }

  function _wrapUpEpoch(address caller) internal {
    vm.startPrank(caller);
    RoninValidatorSet(CONFIG.getAddressFromCurrentNetwork(Contract.RoninValidatorSet.key())).wrapUpEpoch();
    vm.stopPrank();
  }

  function _fastForwardToNextEpoch() internal {
    vm.warp(block.timestamp + 3 seconds);
    vm.roll(block.number + 1);

    uint256 numberOfBlocksInEpoch = RoninValidatorSet(
      CONFIG.getAddressFromCurrentNetwork(Contract.RoninValidatorSet.key())
    ).numberOfBlocksInEpoch();
    uint256 epochEndingBlockNumber = block.number +
      (numberOfBlocksInEpoch - 1) -
      (block.number % numberOfBlocksInEpoch);

    vm.roll(epochEndingBlockNumber);
  }

  function _fastForwardToNextDay() internal {
    _fastForwardToNextEpoch();

    uint256 nextDayTimestamp = block.timestamp + 1 days;
    vm.warp(nextDayTimestamp);
  }
}
