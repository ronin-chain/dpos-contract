// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Contract } from "script/utils/Contract.sol";
import { Maintenance } from "@ronin/contracts/ronin/Maintenance.sol";
import { DPoSMigration } from "../DPoSMigration.s.sol";

contract MaintenanceDeploy is DPoSMigration {
  function _defaultArguments() internal virtual override returns (bytes memory args) { }

  function run() public virtual returns (Maintenance instance) {
    instance = Maintenance(_deployProxy(Contract.Maintenance.key()));
  }
}