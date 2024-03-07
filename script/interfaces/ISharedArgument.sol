// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IRoninTrustedOrganization } from "@ronin/contracts/interfaces/IRoninTrustedOrganization.sol";
import { IGeneralConfig } from "foundry-deployment-kit/interfaces/IGeneralConfig.sol";

interface ISharedArgument is IGeneralConfig {
  struct SharedParameter {
    // RoninTrustedOrganization
    IRoninTrustedOrganization.TrustedOrganization[] trustedOrgs;
    uint256 num;
    uint256 denom;
    // RoninGovernanceAdmin
    uint256 expiryDuration;
  }

  function sharedArguments() external view returns (SharedParameter memory param);
}
