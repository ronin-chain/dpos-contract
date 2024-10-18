// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IRoninTrustedOrganization } from "src/interfaces/IRoninTrustedOrganization.sol";
import { IProfile } from "src/interfaces/IProfile.sol";
import { TConsensus } from "src/udvts/Types.sol";

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

  IProfile private profile;
  IRoninTrustedOrganization private trustedOrg;
  LibVRFProof.VRFKey[] private keys;

  function run() public {
    _deployLogic(Contract.RoninValidatorSet.key());
    _deployLogic(Contract.RoninRandomBeacon.key());
  }
}
