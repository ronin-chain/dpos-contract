// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { FastFinalityTracking } from "@ronin/contracts/ronin/fast-finality/FastFinalityTracking.sol";
import { RoninMigration } from "../RoninMigration.s.sol";
import { Contract } from "../utils/Contract.sol";

contract FastFinalityTrackingDeploy is RoninMigration {
  function _defaultArguments() internal view override returns (bytes memory args) {
    args = abi.encodeCall(
      FastFinalityTracking.initialize, config.getAddressFromCurrentNetwork(Contract.RoninValidatorSet.key())
    );
  }

  function run() public returns (FastFinalityTracking) {
    return FastFinalityTracking(_deployProxy(Contract.FastFinalityTracking.key()));
  }
}
