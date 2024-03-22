// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Profile } from "@ronin/contracts/ronin/profile/Profile.sol";
import { DPoSMigration } from "../DPoSMigration.s.sol";
import { Contract } from "script/utils/Contract.sol";

contract ProfileDeploy is DPoSMigration {
  function _defaultArguments() internal view override returns (bytes memory args) { }

  function run() public returns (Profile instance) {
    instance = Profile(_deployProxy(Contract.Profile.key()));
  }
}
