// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { Staking } from "@ronin/contracts/ronin/staking/Staking.sol";
import { RoninValidatorSet } from "@ronin/contracts/ronin/validator/RoninValidatorSet.sol";
import { RoninRandomBeacon } from "@ronin/contracts/ronin/random-beacon/RoninRandomBeacon.sol";
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

contract Debug_PickValidatorSet_Testnet is RoninMigration {
  using LibVRFProof for *;
  using StdStyle for *;

  Profile private profile;
  Staking private staking;
  RoninRandomBeacon private randomBeacon;
  RoninValidatorSet private validatorSet;
  RoninTrustedOrganization private trustedOrg;
  LibVRFProof.VRFKey[] private keys;

  mapping(address => uint256) private pickCount;

  function run() public {
    profile = Profile(loadContract(Contract.Profile.key()));
    staking = Staking(loadContract(Contract.Staking.key()));
    randomBeacon = RoninRandomBeacon(loadContract(Contract.RoninRandomBeacon.key()));
    validatorSet = RoninValidatorSet(loadContract(Contract.RoninValidatorSet.key()));

    uint256 currentPeriodStartAtBlock = validatorSet.currentPeriodStartAtBlock();
    uint256 startEpoch = validatorSet.epochOf(currentPeriodStartAtBlock);
    uint256 numberOfEpochInPeriod = 144;
    uint256 currPeriod = validatorSet.currentPeriod();

    for (uint256 i; i < numberOfEpochInPeriod; ++i) {
      address[] memory pickedCids = randomBeacon.getSelectedValidatorSet(currPeriod, startEpoch + i);
      for (uint256 j; j < pickedCids.length; ++j) {
        pickCount[pickedCids[j]]++;
      }
    }

    // Log pick count
    address[] memory allCids = validatorSet.getValidatorCandidateIds();
    console.log("Number of Candidates:", allCids.length);
    
    for (uint256 i; i < allCids.length; ++i) {
      (, uint256 staked,) = staking.getPoolDetail(profile.getId2Consensus(allCids[i]));
      string memory log = string.concat(
        "CID: ".yellow(),
        vm.toString(allCids[i]),
        " Staked: ",
        vm.toString(staked / 1 ether),
        " RON".blue(),
        " Pick Count: ",
        vm.toString(pickCount[allCids[i]]),
        " Pick Rate: ".yellow(),
        vm.toString(pickCount[allCids[i]] * 100 / numberOfEpochInPeriod),
        "%"
      );
      console.log(log);
    }
  }
}
