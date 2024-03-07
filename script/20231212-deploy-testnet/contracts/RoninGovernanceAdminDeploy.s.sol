// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninGovernanceAdmin } from "@ronin/contracts/ronin/RoninGovernanceAdmin.sol";
import { Contract } from "script/utils/Contract.sol";
import { ISharedArgument, TestnetMigration } from "../TestnetMigration.s.sol";

contract RoninGovernanceAdminDeploy is TestnetMigration {
  function _defaultArguments() internal virtual override returns (bytes memory args) {
    ISharedArgument.SharedParameter memory param = testnetConfig.sharedArguments();

    args = abi.encode(
      block.chainid,
      config.getAddressFromCurrentNetwork(Contract.RoninTrustedOrganization.key()),
      config.getAddressFromCurrentNetwork(Contract.RoninValidatorSet.key()),
      param.expiryDuration
    );
  }

  function run() public virtual returns (RoninGovernanceAdmin instance) {
    instance = RoninGovernanceAdmin(_deployImmutable(Contract.RoninGovernanceAdmin.key()));
  }
}
