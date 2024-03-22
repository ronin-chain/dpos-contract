// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Staking } from "@ronin/contracts/ronin/staking/Staking.sol";
import { Contract } from "script/utils/Contract.sol";
import { DPoSMigration } from "../DPoSMigration.s.sol";

contract StakingDeploy is DPoSMigration {
  function _defaultArguments() internal virtual override returns (bytes memory args) { }

  function run() public virtual returns (Staking instance) {
    instance = Staking(_deployProxy(Contract.Staking.key()));
  }
}
