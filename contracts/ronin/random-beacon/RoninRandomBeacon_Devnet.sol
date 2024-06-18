// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { RoninRandomBeacon } from "./RoninRandomBeacon.sol";

contract RoninRandomBeacon_Devnet is RoninRandomBeacon {
  /**
   * @dev Manual trigger request random seed for the given period.
   * This function is only used for testing purpose.
   */
  function manualRequestRandomSeed(uint256 period) external {
    _requestRandomSeed(period, _beaconPerPeriod[period - 1].value);
  }

  function _cooldownPeriodThreshold() internal pure override returns (uint256) {
    return 0;
  }
}
