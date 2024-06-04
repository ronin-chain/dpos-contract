// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { FastFinalityTracking } from "@ronin/contracts/ronin/fast-finality/FastFinalityTracking.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";

import { Contract } from "../utils/Contract.sol";

contract FastFinalityTrackingDeploy is RoninMigration {
  function _defaultArguments() internal view override returns (bytes memory args) { }

  function run() public returns (FastFinalityTracking) {
    return FastFinalityTracking(_deployProxy(Contract.FastFinalityTracking.key()));
  }
}
