// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Contract } from "script/utils/Contract.sol";
import { IRoninTrustedOrganization } from "src/interfaces/IRoninTrustedOrganization.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";

contract RoninTrustedOrganizationDeploy is RoninMigration {
  function _defaultArguments() internal virtual override returns (bytes memory args) { }

  function run() public virtual returns (IRoninTrustedOrganization instance) {
    instance = IRoninTrustedOrganization(_deployProxy(Contract.RoninTrustedOrganization.key()));
  }
}
