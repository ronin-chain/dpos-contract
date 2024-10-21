// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IProfile } from "src/interfaces/IProfile.sol";
import { IRoninTrustedOrganization } from "src/interfaces/IRoninTrustedOrganization.sol";
import { TConsensus } from "src/udvts/Types.sol";

import { StdStyle } from "forge-std/StdStyle.sol";
import { console } from "forge-std/console.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";
import { Contract } from "script/utils/Contract.sol";
import { Network } from "script/utils/Network.sol";

import { LibString } from "@solady/utils/LibString.sol";

import { LibPrecompile } from "script/shared/libraries/LibPrecompile.sol";
import { LibVRFProof } from "script/shared/libraries/LibVRFProof.sol";
import { LibWrapUpEpoch } from "script/shared/libraries/LibWrapUpEpoch.sol";

contract Migration_02_SetupVRFKeyHash_ShadowFork_Mainnet is RoninMigration {
  using LibVRFProof for *;
  using StdStyle for *;

  IProfile private profile;
  IRoninTrustedOrganization private trustedOrg;
  LibVRFProof.VRFKey[] private keys;

  function run() public onlyOn(Network.ShadowForkMainnet.key()) {
    profile = IProfile(loadContract(Contract.Profile.key()));
    trustedOrg = IRoninTrustedOrganization(loadContract(Contract.RoninTrustedOrganization.key()));

    IRoninTrustedOrganization.TrustedOrganization[] memory allTrustedOrgs = trustedOrg.getAllTrustedOrganizations();

    uint256 govCount = allTrustedOrgs.length;

    LibVRFProof.VRFKey[] memory _keys = LibVRFProof.genVRFKeys(govCount);
    for (uint256 i; i < _keys.length; ++i) {
      keys.push(_keys[i]);
    }

    for (uint256 i; i < govCount; ++i) {
      address cid = profile.getConsensus2Id(allTrustedOrgs[i].consensusAddr);
      address admin = profile.getId2Admin(cid);

      console.log("\n");
      console.log(string.concat("[gov-", vm.toString(i), "]"));
      console.log("Admin =".yellow(), admin);
      console.log("Consensus =".yellow(), TConsensus.unwrap(allTrustedOrgs[i].consensusAddr));
      console.log("CID =".yellow(), cid);
      console.log("KeyHash =".yellow(), vm.toString(keys[i].keyHash));
      console.log("SecretKey =".yellow(), vm.toString(keys[i].secretKey));
      console.log("Oracle =".yellow(), keys[i].oracle);
      console.log("PrivateKey =".yellow(), LibString.toHexString(keys[i].privateKey));

      vm.broadcast(admin);
      profile.changeVRFKeyHash(cid, keys[i].keyHash);
    }
  }

  function _postCheck() internal virtual override {
    LibPrecompile.deployPrecompile();
    vme.setUserDefinedConfig("vrf-keys", abi.encode(keys));
    LibWrapUpEpoch.wrapUpPeriod();
  }
}
