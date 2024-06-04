// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninValidatorSet } from "@ronin/contracts/ronin/validator/RoninValidatorSet.sol";
import { Contract } from "script/utils/Contract.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";

contract RoninValidatorSetDeploy is RoninMigration {
  function _defaultArguments() internal virtual override returns (bytes memory args) { }

  function run() public virtual returns (RoninValidatorSet instance) {
    instance = RoninValidatorSet(_deployProxy(Contract.RoninValidatorSet.key()));
  }
}
