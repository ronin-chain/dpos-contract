// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Contract } from "../utils/Contract.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";
import { IFastFinalityTracking } from "src/interfaces/IFastFinalityTracking.sol";

contract FastFinalityTrackingDeploy is RoninMigration {
  function _defaultArguments() internal view override returns (bytes memory args) { }

  function run() public returns (IFastFinalityTracking) {
    return IFastFinalityTracking(_deployProxy(Contract.FastFinalityTracking.key()));
  }
}
