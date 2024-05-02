// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Contract } from "script/utils/Contract.sol";
import { RoninRandomBeacon } from "@ronin/contracts/ronin/random-beacon/RoninRandomBeacon.sol";
import { DPoSMigration } from "../DPoSMigration.s.sol";

contract RoninRandomBeaconDeploy is DPoSMigration {
  function _defaultArguments() internal virtual override returns (bytes memory args) { }

  function run() public virtual returns (RoninRandomBeacon instance) {
    instance = RoninRandomBeacon(_deployProxy(Contract.RoninRandomBeacon.key()));
  }
}
