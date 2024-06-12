// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./RoninRandomBeacon.sol";

contract RoninRandomBeacon_Mainnet is RoninRandomBeacon {
  /**
   * @dev Left empty on purpose of matching the contract version with the one in the testnet.
   */
  function initializeV2() external reinitializer(2) { }

  /**
   * @dev Left empty on purpose of matching the contract version with the one in the testnet.
   */
  function initializeV3() external reinitializer(3) { }
}
