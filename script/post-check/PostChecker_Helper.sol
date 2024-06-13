// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StdStyle } from "forge-std/StdStyle.sol";
import { console } from "forge-std/console.sol";

import { BaseMigration } from "@fdk/BaseMigration.s.sol";
import { LibErrorHandler } from "contract-libs/LibErrorHandler.sol";
import { LibVRFProof } from "script/shared/libraries/LibVRFProof.sol";

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
