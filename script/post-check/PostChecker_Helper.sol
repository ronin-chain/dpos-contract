// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StdStyle } from "forge-std/StdStyle.sol";
import { console } from "forge-std/console.sol";
import { VmSafe } from "forge-std/Vm.sol";

import { BaseMigration } from "@fdk/BaseMigration.s.sol";
import { LibErrorHandler } from "contract-libs/LibErrorHandler.sol";
import { Contract } from "../utils/Contract.sol";
import { VRF, LibVRFProof } from "script/shared/libraries/LibVRFProof.sol";
import { ICandidateStaking } from "@ronin/contracts/interfaces/staking/ICandidateStaking.sol";
import { RoninValidatorSet } from "@ronin/contracts/ronin/validator/RoninValidatorSet.sol";
import { RoninRandomBeacon } from "@ronin/contracts/ronin/random-beacon/RoninRandomBeacon.sol";
import { RandomRequest } from "@ronin/contracts/libraries/LibSLA.sol";

abstract contract PostChecker_Helper is BaseMigration {
  uint256 NORMAL_SMALL_NUMBER = 1_000_000;
  uint256 NORMAL_BLOCK_NUMBER = 100_000_000;

  LibVRFProof.VRFKey[] internal _vrfKeys;
  uint private innerLogLevel = 0;

  using LibErrorHandler for bool;

  modifier logPostCheck(string memory task) {
    innerLogLevel++;
    if (innerLogLevel == 1) {
      console.log(string.concat("[>] Post-checking: ", task, "..."));
    }
    _;
    if (innerLogLevel == 1) {
      console.log(StdStyle.green(string.concat("    Check success: ", task, unicode"... ✅")));
    }
    innerLogLevel--;
  }
}
