// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IProfile } from "@ronin/contracts/interfaces/IProfile.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";
import { Contract } from "../utils/Contract.sol";

contract ProfileDeploy is RoninMigration {
  function _defaultArguments() internal view override returns (bytes memory args) { }

  function run() public returns (IProfile) {
    return IProfile(_deployProxy(Contract.Profile.key()));
  }
}
