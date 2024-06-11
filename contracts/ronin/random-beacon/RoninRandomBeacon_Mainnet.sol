// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./RoninRandomBeacon.sol";

contract RoninRandomBeacon_Mainnet is RoninRandomBeacon {
  function initializeV2() external reinitializer(2) { }

  function initializeV3() external reinitializer(3) { }
}
