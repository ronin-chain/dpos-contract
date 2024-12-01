// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibErrorHandler } from "@fdk/libraries/LibErrorHandler.sol";
import { LibSharedAddress } from "@fdk/libraries/LibSharedAddress.sol";
import { Vm } from "forge-std/Vm.sol";

import { ICandidateStaking } from "src/interfaces/staking/ICandidateStaking.sol";

library LibApplyCandidate {
  using LibErrorHandler for bool;

  Vm internal constant vm = Vm(LibSharedAddress.VM);

  function applyValidatorCandidate(address staking, address candidateAdmin, address consensusAddr) internal {
    uint256 value = ICandidateStaking(staking).minValidatorStakingAmount();
    applyValidatorCandidate(staking, candidateAdmin, consensusAddr, value);
  }

  function applyValidatorCandidate(
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
        1500,
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
          1500,
          bytes(string.concat("mock-pub-key", vm.toString(candidateAdmin)))
        )
      );
    }

    // Before REP-3 ABI
    if (!success) {
      (success, returnData) = staking.call{ value: value }(
        abi.encodeWithSelector(
          ICandidateStaking.applyValidatorCandidate.selector, candidateAdmin, consensusAddr, candidateAdmin, 1500
        )
      );
    }
    vm.stopPrank();
    success.handleRevert(ICandidateStaking.applyValidatorCandidate.selector, returnData);
  }
}
