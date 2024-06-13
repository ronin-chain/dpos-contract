// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { RoninRandomBeacon } from "./RoninRandomBeacon.sol";

contract RoninRandomBeacon_Devnet is RoninRandomBeacon {
  /**
   * @dev Left empty on purpose of matching the contract version with the one in the testnet.
   */
  function initializeV2() external reinitializer(2) { }

  /**
   * @dev Left empty on purpose of matching the contract version with the one in the testnet.
   */
  function initializeV3() external reinitializer(3) { }

  /**
   * @dev Manual trigger request random seed for the given period.
   * This function is only used for testing purpose.
   */
  function manualRequestRandomSeed(uint256 period) external {
    _requestRandomSeed(period, _beaconPerPeriod[period - 1].value);
  }

  function COOLDOWN_PERIOD_THRESHOLD() public pure override returns (uint256) {
    return 0;
  }
}
