// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninMigration } from "script/RoninMigration.s.sol";
import { Contract } from "script/utils/Contract.sol";
import { IRoninValidatorSet } from "src/interfaces/validator/IRoninValidatorSet.sol";

contract RoninValidatorSetDeploy is RoninMigration {
  function _defaultArguments() internal virtual override returns (bytes memory args) { }

  function run() public virtual returns (IRoninValidatorSet instance) {
    instance = IRoninValidatorSet(_deployProxy(Contract.RoninValidatorSet.key()));
  }
}
