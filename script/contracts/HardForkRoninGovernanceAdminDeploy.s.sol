// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninGovernanceAdmin } from "@ronin/contracts/ronin/RoninGovernanceAdmin.sol";
import { ISharedArgument, RoninMigration } from "../RoninMigration.s.sol";
import { Contract } from "../utils/Contract.sol";

contract HardForkRoninGovernanceAdminDeploy is RoninMigration {
  function _defaultArguments() internal view override returns (bytes memory args) {
    ISharedArgument.SharedParameter memory param = config.sharedArguments();

    args = abi.encode(
      block.chainid,
      config.getAddressFromCurrentNetwork(Contract.RoninTrustedOrganization.key()),
      config.getAddressFromCurrentNetwork(Contract.RoninValidatorSet.key()),
      param.expiryDuration
    );
  }

  function run() public returns (RoninGovernanceAdmin) {
    return RoninGovernanceAdmin(_deployImmutable(Contract.HardForkRoninGovernanceAdmin.key()));
  }
}
