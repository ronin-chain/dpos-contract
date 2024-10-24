// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninMigration } from "script/RoninMigration.s.sol";
import { Contract } from "script/utils/Contract.sol";
import { IRandomBeacon } from "src/interfaces/random-beacon/IRandomBeacon.sol";

contract RoninRandomBeaconDeploy is RoninMigration {
  function _defaultArguments() internal virtual override returns (bytes memory args) { }

  function run() public virtual returns (IRandomBeacon instance) {
    instance = IRandomBeacon(_deployProxy(Contract.RoninRandomBeacon.key()));
  }
}
