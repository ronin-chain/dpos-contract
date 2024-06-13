// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninTrustedOrganization } from "@ronin/contracts/multi-chains/RoninTrustedOrganization.sol";
import { IRoninTrustedOrganization } from "@ronin/contracts/interfaces/IRoninTrustedOrganization.sol";
import { Profile } from "@ronin/contracts/ronin/profile/Profile.sol";
import { TConsensus } from "@ronin/contracts/udvts/Types.sol";

import { console } from "forge-std/console.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";
import { Contract } from "script/utils/Contract.sol";
import { Network } from "script/utils/Network.sol";

import { LibString } from "@solady/utils/LibString.sol";
import { LibVRFProof } from "script/shared/libraries/LibVRFProof.sol";
import { LibPrecompile } from "script/shared/libraries/LibPrecompile.sol";
import { LibWrapUpEpoch } from "script/shared/libraries/LibWrapUpEpoch.sol";

contract Migration_ShadowForkMainnet_Upgrade_RoninValidatorSet is RoninMigration {
  using LibVRFProof for *;
  using StdStyle for *;

  Profile private profile;
  RoninTrustedOrganization private trustedOrg;
  LibVRFProof.VRFKey[] private keys;

  function run() public {
    _upgradeProxy(Contract.RoninValidatorSet.key());
  }
}
