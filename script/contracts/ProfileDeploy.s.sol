// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Profile } from "@ronin/contracts/ronin/profile/Profile.sol";
import { RoninMigration } from "../RoninMigration.s.sol";
import { Contract } from "../utils/Contract.sol";

contract ProfileDeploy is RoninMigration {
  function _defaultArguments() internal view override returns (bytes memory args) {
    args = abi.encodeCall(Profile.initialize, config.getAddressFromCurrentNetwork(Contract.RoninValidatorSet.key()));
  }

  function run() public returns (Profile) {
    return Profile(_deployProxy(Contract.Profile.key()));
  }
}
