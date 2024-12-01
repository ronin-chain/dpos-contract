// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninMigration } from "script/RoninMigration.s.sol";
import { Contract } from "script/utils/Contract.sol";
import { IMaintenance } from "src/interfaces/IMaintenance.sol";

contract MaintenanceDeploy is RoninMigration {
  function _defaultArguments() internal virtual override returns (bytes memory args) { }

  function run() public virtual returns (IMaintenance instance) {
    instance = IMaintenance(_deployProxy(Contract.Maintenance.key()));
  }
}
