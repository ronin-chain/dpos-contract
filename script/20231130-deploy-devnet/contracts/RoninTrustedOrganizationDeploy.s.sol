// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Contract } from "script/utils/Contract.sol";
import { RoninTrustedOrganization } from "@ronin/contracts/multi-chains/RoninTrustedOrganization.sol";
import { DevnetMigration } from "../DevnetMigration.s.sol";

contract RoninTrustedOrganizationDeploy is DevnetMigration {
  function _defaultArguments() internal virtual override returns (bytes memory args) { }

  function run() public virtual returns (RoninTrustedOrganization instance) {
    instance = RoninTrustedOrganization(_deployProxy(Contract.RoninTrustedOrganization.key()));
  }
}
