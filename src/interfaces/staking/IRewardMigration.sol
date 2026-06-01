// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IRewardMigration {
  /**
   * @dev Migrate reward to the address `to`.
   *
   * Requirements:
   * - The method caller must be staking contract.
   */
  function migrateReward(
    address to,
    uint256 amount
  ) external;
}
