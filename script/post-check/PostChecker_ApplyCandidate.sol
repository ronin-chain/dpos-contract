// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ICandidateStaking } from "@ronin/contracts/interfaces/staking/ICandidateStaking.sol";
import { RoninValidatorSet } from "@ronin/contracts/ronin/validator/RoninValidatorSet.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { console2 as console } from "forge-std/console2.sol";
import { TContract } from "foundry-deployment-kit/types/Types.sol";
import { LibProxy } from "foundry-deployment-kit/libraries/LibProxy.sol";
import { BaseMigration } from "foundry-deployment-kit/BaseMigration.s.sol";
import { Contract } from "../utils/Contract.sol";
import "./PostChecker_Helper.sol";

abstract contract PostChecker_ApplyCandidate is BaseMigration, PostChecker_Helper {
  using LibProxy for *;

  address private _validatorSet;
  address private _staking;

  function _postCheck__ApplyCandidate() internal {
    _validatorSet = CONFIG.getAddressFromCurrentNetwork(Contract.RoninValidatorSet.key());
    _staking = CONFIG.getAddressFromCurrentNetwork(Contract.Staking.key());

    _postCheck_ApplyingCandidate_EOA();
    // _postCheck_ApplyingCandidate_Multisig();
  }

  function _postCheck_ApplyingCandidate_EOA() private logFn("Post check applying candidate") {
    address candidateAdmin = makeAddr("mock-candidate-admin-t1");
    address consensusAddr = makeAddr("mock-consensus-addr-t1");

    _applyValidatorCandidate(_staking, candidateAdmin, consensusAddr);

    _fastForwardToNextDay();
    _wrapUpEpoch();

    candidateAdmin = makeAddr("mock-candidate-admin-t2");
    consensusAddr = makeAddr("mock-consensus-addr-t2");

    _applyValidatorCandidate(_staking, candidateAdmin, consensusAddr);

    RoninValidatorSet(payable(_validatorSet)).isValidatorCandidate(consensusAddr);

    console.log(">", StdStyle.green("Post check Staking `applyValidatorCandidate` for EOA successful"));
  }

  function _postCheck_ApplyingCandidate_Multisig() private logFn("Post check applying candidate for multisig") {
    address candidateAdmin = makeAddr("multisig-candidate-admin");
    address consensusAddr = makeAddr("multisig-consensus-addr");

    vm.etch(
      candidateAdmin,
      hex"608060405273ffffffffffffffffffffffffffffffffffffffff600054167fa619486e0000000000000000000000000000000000000000000000000000000060003514156050578060005260206000f35b3660008037600080366000845af43d6000803e60008114156070573d6000fd5b3d6000f3fea2646970667358221220d1429297349653a4918076d650332de1a1068c5f3e07c5c82360c277770b955264736f6c63430007060033"
    );

    _applyValidatorCandidate(_staking, candidateAdmin, consensusAddr);

    RoninValidatorSet(payable(_validatorSet)).isValidatorCandidate(consensusAddr);

    console.log(">", StdStyle.green("Post check Staking `applyValidatorCandidate` for multisig successful"));
  }
}
