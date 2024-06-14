// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ITimingInfo {
  /// @dev Throws if the period has not ended yet or the period ending block does not exist.
  error ErrPeriodNotEndedYet(uint256 period);
  /// @dev Throws if the period ending block does not exist.
  error ErrPeriodEndingBlockNotTracked(uint256 period, uint256 firstTrackedPeriod);

  /**
   * @dev Returns the block that validator set was updated.
   */
  function getLastUpdatedBlock() external view returns (uint256);

  /**
   * @dev Returns the number of blocks in a epoch.
   */
  function numberOfBlocksInEpoch() external view returns (uint256 _numberOfBlocks);

  /**
   * @dev Returns the epoch index from the block number.
   */
  function epochOf(uint256 _block) external view returns (uint256);

  /**
   * @dev Returns whether the epoch ending is at the block number `_block`.
   */
  function epochEndingAt(uint256 _block) external view returns (bool);

  /**
   * @dev Returns the period index from given epoch number.
   */
  function getPeriodOf(uint256 epoch) external view returns (uint256 period);

  /**
   * @dev Returns the block number that `period` ending at.
   *
   * Throws error if the period has not ended yet.
   * Throws error if the period ending block does not exist.
   *
   * @param period The period index.
   */
  function getPeriodEndBlock(uint256 period) external view returns (uint256 blockNumber);

  /**
   * @dev Tries to get the period index from the epoch number.
   */
  function tryGetPeriodOfEpoch(uint256 _epoch) external view returns (bool _filled, uint256 _periodNumber);

  /**
   * @dev Returns whether the period ending at the current block number.
   */
  function isPeriodEnding() external view returns (bool);

  /**
   * @dev Returns the period index from the current block.
   */
  function currentPeriod() external view returns (uint256);

  /**
   * @dev Returns the block number that the current period starts at.
   */
  function currentPeriodStartAtBlock() external view returns (uint256);
}
