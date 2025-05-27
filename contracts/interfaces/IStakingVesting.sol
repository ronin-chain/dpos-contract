// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IStakingVesting {
  /**
   * @dev Error thrown when attempting to send a bonus that has already been sent.
   */
  error ErrBonusAlreadySent();

  /**
   * @dev Error thrown when the bonus amount is out of bound.
   * @param value The value that is out of bound.
   * @param min The minimum bound.
   * @param max The maximum bound.
   */
  error ErrOutOfBound(uint256 value, uint256 min, uint256 max);

  /**
   * @notice Error thrown when blocks are out of order.
   * @param index The index of the element that caused the error.
   * @param currBlock The current block number.
   * @param prvBlock The previous block number.
   * @dev This error is raised when currBlock is not greater than prvBlock, indicating a sequence violation.
   */
  error ErrOutOfOrder(uint256 index, uint256 currBlock, uint256 prvBlock);

  /**
   * @notice Error thrown when an array is empty but is expected to contain elements
   * @dev This error is thrown in operations that require a non-empty array
   */
  error ErrEmptyArray();

  struct Reward {
    uint64 startBlock;
    uint64 amount; // Max reward is ~18 RON per block
  }

  /**
   * @dev Emitted when the block reward range is updated.
   */
  event BlockRewardRangeUpdated(address indexed by, uint256 minRewardAmount, uint256 maxRewardAmount);
  /// @dev Emitted when the block bonus for block producer is transferred.
  event BonusTransferred(
    uint256 indexed blockNumber, address indexed recipient, uint256 blockProducerAmount, uint256 bridgeOperatorAmount
  );
  /// @dev Emitted when the transfer of block bonus for block producer is failed.
  event BonusTransferFailed(
    uint256 indexed blockNumber,
    address indexed recipient,
    uint256 blockProducerAmount,
    uint256 bridgeOperatorAmount,
    uint256 contractBalance
  );
  /// @dev Emitted when the block bonus for block producer is updated
  event BlockProducerBonusPerBlockUpdated(address indexed by, Reward[] blockRewards);
  /// @dev Emitted when the percent of fast finality reward is updated
  event FastFinalityRewardPercentageUpdated(uint256);
  /// @dev Emitted when the percent of fast finality reward for REP10 is updated
  event FastFinalityRewardPercentageUpdatedForREP10(uint256);

  function initialize(
    address validatorContract,
    uint256 blockProducerBonusPerBlock,
    uint256 bridgeOperatorBonusPerBlock
  ) external payable;

  function initializeV2() external;

  function initializeV3(uint256 fastFinalityRewardPercent) external;

  function initializeV4(uint256 activatedAtPeriod, uint256 fastFinalityRewardPercentREP10) external;

  /**
   * @dev Returns the destined period that REP10 is activated.
   */
  function getREP10ActivatedAtPeriod() external view returns (uint256);

  /**
   * @dev Returns the bonus amount for the block producer at `blockNum`.
   */
  function blockProducerBlockBonus(
    uint256 blockNum
  ) external view returns (uint64);

  /**
   * @dev Returns the percentage of fast finality reward.
   */
  function fastFinalityRewardPercentage() external view returns (uint256);

  /**
   * @dev Receives RON from any address.
   */
  function receiveRON() external payable;

  /**
   * @dev Returns the last block number that the staking vesting is sent.
   */
  function lastBlockSendingBonus() external view returns (uint256);

  /**
   * @dev Transfers the staking vesting for the block producer and the bridge operator whenever a new block is mined.
   *
   * Requirements:
   * - The method caller must be validator contract.
   * - The method must be called only once per block.
   *
   * Emits the event `BonusTransferred` or `BonusTransferFailed`.
   *
   * Notes:
   * - The method does not revert when the contract balance is insufficient to send bonus. This assure the submit reward method
   * will not be reverted, and the underlying nodes does not hang.
   *
   * @param forBlockProducer Indicates whether requesting the bonus for the block producer, in case of being in jail or relevance.
   * @param forBridgeOperator Deprecated, no longer used.
   *
   * @return success Whether the transfer is successfully. This returns false mostly because this contract is out of balance.
   * @return blockProducerBonus The amount of bonus actually sent for the block producer, returns 0 when the transfer is failed.
   * @return bridgeOperatorBonus The amount of bonus actually sent for the bridge operator, returns 0 when the transfer is failed.
   * @return fastFinalityRewardPercentage The percent of fast finality reward, returns 0 when the transfer is failed.
   *
   */
  function requestBonus(
    bool forBlockProducer,
    bool forBridgeOperator
  )
    external
    returns (
      bool success,
      uint256 blockProducerBonus,
      uint256 bridgeOperatorBonus, // Always 0, deprecated
      uint256 fastFinalityRewardPercentage
    );

  /**
   * @dev Updates the block rewards for block producers
   *
   * Requirements:
   * - Only callable by admin
   * - Throw ErrEmptyArray If the rewards array is empty
   * - Throw ErrOutOfBound If any reward amount is outside the min-max range
   * - Throw ErrOutOfOrder If the startBlocks are not in descending order
   * emits `BlockProducerBonusPerBlockUpdated` when block rewards are updated
   *
   * @param rewards An array of Reward structs, each containing a startBlock and amount
   */
  function updateBlockRewards(
    Reward[] calldata rewards
  ) external;

  /**
   * @dev Sets the percent of fast finality reward.
   *
   * Emits the event `FastFinalityRewardPercentageUpdated`.
   *
   * Requirements:
   * - The method caller is admin.
   *
   */
  function setFastFinalityRewardPercentage(
    uint256 _percent
  ) external;

  /**
   * @dev This function allows setting the minimum and maximum amounts for block rewards
   */
  function setBlockRewardRange(uint64 minRewardAmount, uint64 maxRewardAmount) external;

  /**
   * @dev Returns the minimum and maximum amounts for block rewards.
   */
  function getBlockRewardRange() external view returns (uint64 minRewardAmount, uint64 maxRewardAmount);

  /**
   * @dev Returns the block rewards for block producers.
   * @return An array of Reward structs, each containing a startBlock and amount
   */
  function getBlockRewards() external view returns (Reward[] memory);
}
