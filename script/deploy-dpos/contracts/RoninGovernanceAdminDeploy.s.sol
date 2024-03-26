// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninGovernanceAdmin } from "@ronin/contracts/ronin/RoninGovernanceAdmin.sol";
import { Contract } from "script/utils/Contract.sol";
import { ISharedArgument, DPoSMigration } from "../DPoSMigration.s.sol";

contract RoninGovernanceAdminDeploy is DPoSMigration {
  function _defaultArguments() internal virtual override returns (bytes memory args) {
    ISharedArgument.GovernanceAdminParam memory param = cfg.sharedArguments().governanceAdmin;

    args = abi.encode(
      block.chainid,
      config.getAddressFromCurrentNetwork(Contract.RoninTrustedOrganization.key()),
      config.getAddressFromCurrentNetwork(Contract.RoninValidatorSet.key()),
      param.proposalExpiryDuration
    );
  }

  function run() public virtual returns (RoninGovernanceAdmin instance) {
    instance = RoninGovernanceAdmin(_deployImmutable(Contract.RoninGovernanceAdmin.key()));
  }
}
