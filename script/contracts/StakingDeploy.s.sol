// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStaking } from "@ronin/contracts/interfaces/staking/IStaking.sol";
import { Contract } from "script/utils/Contract.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";

contract StakingDeploy is RoninMigration {
  function _defaultArguments() internal virtual override returns (bytes memory args) { }

  function run() public virtual returns (IStaking instance) {
    instance = IStaking(_deployProxy(Contract.Staking.key()));
  }
}
