// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Contract } from "../utils/Contract.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";
import { IProfile } from "src/interfaces/IProfile.sol";

contract ProfileDeploy is RoninMigration {
  function _defaultArguments() internal view override returns (bytes memory args) { }

  function run() public returns (IProfile) {
    return IProfile(_deployProxy(Contract.Profile.key()));
  }
}
