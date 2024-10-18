// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ISharedArgument, RoninMigration } from "../RoninMigration.s.sol";
import { Contract } from "../utils/Contract.sol";
import { IRoninTrustedOrganization } from "src/interfaces/IRoninTrustedOrganization.sol";

contract TemporalRoninTrustedOrganizationDeploy is RoninMigration {
  function _defaultArguments() internal view override returns (bytes memory args) {
    ISharedArgument.RoninTrustedOrganizationParam memory param = config.sharedArguments().roninTrustedOrganization;
    args = abi.encodeCall(
      IRoninTrustedOrganization.initialize, (param.trustedOrganizations, param.numerator, param.denominator)
    );
  }

  function run() public returns (IRoninTrustedOrganization) {
    return IRoninTrustedOrganization(_deployProxy(Contract.TemporalRoninTrustedOrganization.key()));
  }
}
