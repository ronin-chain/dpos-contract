// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninGovernanceAdmin } from "@ronin/contracts/ronin/RoninGovernanceAdmin.sol";
import { Contract } from "script/utils/Contract.sol";
import { ISharedArgument, RoninMigration } from "../RoninMigration.s.sol";

contract RoninGovernanceAdminDeploy is RoninMigration {
  function _defaultArguments() internal virtual override returns (bytes memory args) {
    ISharedArgument.RoninGovernanceAdminParam memory param = config.sharedArguments().roninGovernanceAdmin;

    args = abi.encode(
      block.chainid,
      loadContract(Contract.RoninTrustedOrganization.key()),
      loadContract(Contract.RoninValidatorSet.key()),
      param.proposalExpiryDuration
    );
  }

  function run() public virtual returns (RoninGovernanceAdmin instance) {
    instance = RoninGovernanceAdmin(_deployImmutable(Contract.RoninGovernanceAdmin.key()));
  }
}
