// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../interfaces/consumers/PeriodWrapperConsumer.sol";

import { TConsensus, TPoolId } from "../../udvts/Types.sol";

interface IRewardPool is PeriodWrapperConsumer {
  struct UserRewardFields {
    // Recorded reward amount.
    uint256 debited;
    // The last accumulated of the amount rewards per share (one unit staking) that the info updated.
    uint256 aRps;
    // Lowest staking amount in the period.
    uint256 lowestAmount;
    // Last period number that the info updated.
    uint256 lastPeriod;
  }

  struct PoolFields {
    // Accumulated of the amount rewards per share (one unit staking).
    uint256 aRps;
    // The staking total to share reward of the current period.
    PeriodWrapper shares;
  }

  /// @dev Emitted when the fields to calculate pending reward for the user is updated.
  event UserRewardUpdated(address indexed poolId, address indexed user, uint256 debited);
  /// @dev Emitted when the user claimed their reward
  event RewardClaimed(address indexed poolId, address indexed user, uint256 amount);

  /// @dev Emitted when the pool shares are updated
  event PoolSharesUpdated(uint256 indexed period, address indexed poolId, uint256 shares);
  /// @dev Emitted when the pools are updated
  event PoolsUpdated(uint256 indexed period, address[] poolIds, uint256[] aRps, uint256[] shares);
  /// @dev Emitted when the contract fails when updating the pools
  event PoolsUpdateFailed(uint256 indexed period, address[] poolIds, uint256[] rewards);
  /// @dev Emitted when the contract fails when updating the pools that already set
  event PoolsUpdateConflicted(uint256 indexed period, address[] poolIds);

  /// @dev Error of invalid pool share.
  error ErrInvalidPoolShare();

  /**
   * @dev Returns the reward amount that user claimable.
   */
  function getReward(TConsensus consensusAddr, address user) external view returns (uint256);

  /**
   * @dev Returns the reward amount that user claimable.
   */
  function getRewardById(address poolId, address user) external view returns (uint256);

  /**
   * @dev Returns the staking amount of an user.
   */
  function getStakingAmount(TConsensus consensusAddr, address user) external view returns (uint256);

  /**
   * @dev Returns the staking amounts of the users.
   */
  function getManyStakingAmounts(
    TConsensus[] calldata consensusAddrs,
    address[] calldata userList
  ) external view returns (uint256[] memory);

  function getManyStakingAmountsById(
    address[] calldata poolIds,
    address[] calldata userList
  ) external view returns (uint256[] memory);

  /**
   * @dev Returns the total staking amount of all users for a pool.
   */
  function getStakingTotal(
    TConsensus consensusAddr
  ) external view returns (uint256);

  /**
   * @dev Returns the total staking amounts of all users for the pools corresponding to `consensusAddrs`.
   */
  function getManyStakingTotals(
    TConsensus[] calldata consensusAddrs
  ) external view returns (uint256[] memory);

  /**
   * @dev Returns the total staking amounts of all users for the pools `poolIds`.
   */
  function getManyStakingTotalsById(
    address[] calldata poolIds
  ) external view returns (uint256[] memory stakingAmounts_);
}
