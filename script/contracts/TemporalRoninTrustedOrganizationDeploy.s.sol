// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninTrustedOrganization } from "@ronin/contracts/multi-chains/RoninTrustedOrganization.sol";
import { ISharedArgument, RoninMigration } from "../RoninMigration.s.sol";
import { Contract } from "../utils/Contract.sol";

contract TemporalRoninTrustedOrganizationDeploy is RoninMigration {
  function _defaultArguments() internal view override returns (bytes memory args) {
    ISharedArgument.RoninTrustedOrganizationParam memory param = config.sharedArguments().roninTrustedOrganization;
    args = abi.encodeCall(
      RoninTrustedOrganization.initialize, (param.trustedOrganizations, param.numerator, param.denominator)
    );
  }

  function run() public returns (RoninTrustedOrganization) {
    return RoninTrustedOrganization(_deployProxy(Contract.TemporalRoninTrustedOrganization.key()));
  }
}
