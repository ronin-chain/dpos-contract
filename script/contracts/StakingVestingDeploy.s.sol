// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StakingVesting } from "@ronin/contracts/ronin/StakingVesting.sol";
import { Contract } from "script/utils/Contract.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";


contract StakingVestingDeploy is RoninMigration {
  function _defaultArguments() internal virtual override returns (bytes memory args) { }

  function run() public virtual returns (StakingVesting instance) {
    instance = StakingVesting(_deployProxy(Contract.StakingVesting.key()));
  }
}
