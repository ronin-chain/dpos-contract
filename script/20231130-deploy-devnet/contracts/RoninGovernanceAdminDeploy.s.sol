// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninGovernanceAdmin } from "@ronin/contracts/ronin/RoninGovernanceAdmin.sol";
import { Contract } from "script/utils/Contract.sol";
import { ISharedArgument, DevnetMigration } from "../DevnetMigration.s.sol";

contract RoninGovernanceAdminDeploy is DevnetMigration {
  function _defaultArguments() internal virtual override returns (bytes memory args) {
    ISharedArgument.SharedParameter memory param = devnetConfig.sharedArguments();

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
