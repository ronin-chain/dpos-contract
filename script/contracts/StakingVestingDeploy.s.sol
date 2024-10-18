// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninMigration } from "script/RoninMigration.s.sol";
import { Contract } from "script/utils/Contract.sol";
import { IStakingVesting } from "src/interfaces/IStakingVesting.sol";

contract StakingVestingDeploy is RoninMigration {
  function _defaultArguments() internal virtual override returns (bytes memory args) { }

  function run() public virtual returns (IStakingVesting instance) {
    instance = IStakingVesting(_deployProxy(Contract.StakingVesting.key()));
  }
}
