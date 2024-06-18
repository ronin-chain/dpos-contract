// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninGovernanceAdmin } from "@ronin/contracts/ronin/RoninGovernanceAdmin.sol";
import { ISharedArgument, RoninMigration } from "../RoninMigration.s.sol";
import { Contract } from "../utils/Contract.sol";

contract HardForkRoninGovernanceAdminDeploy is RoninMigration {
  function _defaultArguments() internal view override returns (bytes memory args) {
    ISharedArgument.RoninGovernanceAdminParam memory param = config.sharedArguments().roninGovernanceAdmin;

    args = abi.encode(
      block.chainid,
      loadContract(Contract.RoninTrustedOrganization.key()),
      loadContract(Contract.RoninValidatorSet.key()),
      param.proposalExpiryDuration
    );
  }

  function run() public returns (RoninGovernanceAdmin) {
    return RoninGovernanceAdmin(_deployImmutable(Contract.HardForkRoninGovernanceAdmin.key()));
  }
}
