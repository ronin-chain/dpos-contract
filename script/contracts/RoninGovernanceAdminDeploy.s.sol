// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IRoninGovernanceAdmin } from "src/interfaces/IRoninGovernanceAdmin.sol";
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

  function run() public virtual returns (IRoninGovernanceAdmin instance) {
    instance = IRoninGovernanceAdmin(_deployImmutable(Contract.RoninGovernanceAdmin.key()));
  }
}
