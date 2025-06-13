// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Contract } from "../utils/Contract.sol";

import "./PostChecker_Helper.sol";
import { BaseMigration } from "@fdk/BaseMigration.s.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";

import { LibApplyCandidate } from "script/shared/libraries/LibApplyCandidate.sol";
import { LibWrapUpEpoch } from "script/shared/libraries/LibWrapUpEpoch.sol";
import { ICandidateManager } from "src/interfaces/validator/ICandidateManager.sol";

abstract contract PostChecker_ApplyCandidate is BaseMigration, PostChecker_Helper {
  using LibProxy for *;

  address private _validatorSet;
  address private _staking;

  function _postCheck__ApplyCandidate() internal {
    _validatorSet = loadContract(Contract.RoninValidatorSet.key());
    _staking = loadContract(Contract.Staking.key());

    _postCheck_ApplyingCandidate_EOA();
    _postCheck_ApplyingCandidate_Multisig();

    LibWrapUpEpoch.wrapUpPeriod();
  }

  function _postCheck_ApplyingCandidate_EOA() private logPostCheck("[ValidatorSet] applying candidate EOA") {
    address candidateAdmin = makeAddr("mock-candidate-admin-t1");
    address consensusAddr = makeAddr("mock-consensus-addr-t1");

    LibApplyCandidate.applyValidatorCandidate(_staking, candidateAdmin, consensusAddr);

    LibWrapUpEpoch.wrapUpPeriod();

    candidateAdmin = makeAddr("mock-candidate-admin-t2");
    consensusAddr = makeAddr("mock-consensus-addr-t2");

    LibApplyCandidate.applyValidatorCandidate(_staking, candidateAdmin, consensusAddr);

    (, bytes memory returnData) =
      _validatorSet.staticcall(abi.encodeWithSelector(ICandidateManager.isValidatorCandidate.selector, consensusAddr));
    assertTrue(abi.decode(returnData, (bool)));
  }

  function _postCheck_ApplyingCandidate_Multisig() private logPostCheck("[ValidatorSet] applying candidate multisig") {
    address candidateAdmin = makeAddr("multisig-candidate-admin");
    address consensusAddr = makeAddr("multisig-consensus-addr");

    vm.etch(
      candidateAdmin,
      hex"608060405273ffffffffffffffffffffffffffffffffffffffff600054167fa619486e0000000000000000000000000000000000000000000000000000000060003514156050578060005260206000f35b3660008037600080366000845af43d6000803e60008114156070573d6000fd5b3d6000f3fea2646970667358221220d1429297349653a4918076d650332de1a1068c5f3e07c5c82360c277770b955264736f6c63430007060033"
    );

    LibApplyCandidate.applyValidatorCandidate(_staking, candidateAdmin, consensusAddr);

    (, bytes memory returnData) =
      _validatorSet.staticcall(abi.encodeWithSelector(ICandidateManager.isValidatorCandidate.selector, consensusAddr));
    assertTrue(abi.decode(returnData, (bool)));
  }
}
