// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Contract } from "script/utils/Contract.sol";
import { FastFinalityTracking } from "@ronin/contracts/ronin/fast-finality/FastFinalityTracking.sol";
import { TestnetMigration } from "../TestnetMigration.s.sol";

contract FastFinalityTrackingDeploy is TestnetMigration {
  function _defaultArguments() internal virtual override returns (bytes memory args) { }

  function run() public virtual returns (FastFinalityTracking instance) {
    instance = FastFinalityTracking(_deployProxy(Contract.FastFinalityTracking.key()));
  }
}
