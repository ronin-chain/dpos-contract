// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IBaseFeeTreasury {
  event Withdrawn(address indexed by, address indexed to, uint256 amount);

  /**
   * @dev Withdraws the specified amount to the specified address.
   * Only `RoninGovernanceAdmin` can call this function.
   */
  function withdrawTo(address to, uint256 amount) external;
}
