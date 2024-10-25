// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./ISlashingExecution.sol";

interface ICoinbaseExecution is ISlashingExecution {
  enum BlockRewardDeprecatedType {
    UNKNOWN,
    UNAVAILABILITY,
    AFTER_BAILOUT
  }

  /// @dev Emitted when the sum of fast finality score of current validator ids is zero.
  event ZeroSumFastFinalityScore(uint256 indexed epoch, address[] cids);
  /// @dev Emitted when the validator set is returned empty from `RoninRandomBeacon` contract. Fallback to Governing Validator Set.
  event EmptyValidatorSet(uint256 indexed period, uint256 indexed epoch, address[] fallbackCids);
  /// @dev Emitted when the validator set is updated
  event ValidatorSetUpdated(uint256 indexed period, uint256 indexed epoch, address[] cids);
  /// @dev Emitted when the block producer operator set is updated, to mirror the in-jail and maintaining status of the validator.
  event BlockProducerSetUpdated(uint256 indexed period, uint256 indexed epoch, address[] cids);

  /// @dev Emitted when the reward of the block producer is deprecated.
  event BlockRewardDeprecated(address indexed cid, uint256 rewardAmount, BlockRewardDeprecatedType deprecatedType);
  /// @dev Emitted when the block reward is submitted.
  event BlockRewardSubmitted(address indexed cid, uint256 submittedAmount, uint256 bonusAmount);
  /// @dev Emitted when the L2 tx fee is submitted.
  event L2BlockRewardSubmitted(address indexed cid, uint256 submittedAmount);

  /// @dev Emitted when the mining reward of corresponding l2 is distributed.
  event L2MiningRewardDistributed(address indexed cid, address indexed recipient, uint256 amount);
  /// @dev Emitted when the contract fails when distributing the mining reward of corresponding l2.
  event L2MiningRewardDistributionFailed(
    address indexed cid, address indexed recipient, uint256 amount, uint256 contractBalance
  );
  /// @dev Emitted when the block producer reward is distributed.
  event MiningRewardDistributed(address indexed cid, address indexed recipient, uint256 amount);
  /// @dev Emitted when the contract fails when distributing the block producer reward.
  event MiningRewardDistributionFailed(
    address indexed cid, address indexed recipient, uint256 amount, uint256 contractBalance
  );

  /// @dev Emitted when the fast finality reward is distributed to validator.
  event FastFinalityRewardDistributed(address indexed cid, address indexed recipient, uint256 amount);
  /// @dev Emitted when the contract fails when distributing the fast finality reward to validator.
  event FastFinalityRewardDistributionFailed(
    address indexed cid, address indexed recipient, uint256 amount, uint256 contractBalance
  );

  /// @dev Emitted when the L2 tx fee is distributed to the delegator.
  event L2MiningRewardDelegatorsDistributed(address[] cids, uint256[] delegatingAmounts);
  /// @dev Emitted when the contract fails when distributing the L2 tx fee to the delegator.
  event L2MiningRewardDelegatorsDistributionFailed(
    address[] cids, uint256[] delegatingAmounts, uint256 contractBalance
  );
  /// @dev Emitted when the amount of block mining reward is distributed to staking contract for delegators.
  event MiningRewardDelegatorsDistributed(address[] cids, uint256[] delegatingAmounts);
  /// @dev Emitted when the contracts fails when distributing the amount of RON to the staking contract for delegators.
  event MiningRewardDelegatorsDistributionFailed(address[] cids, uint256[] delegatingAmounts, uint256 contractBalance);
  /// @dev Emitted when the fast finality rewards for delegators is distributed to staking contract for delegators.
  event FastFinalityRewardDelegatorsDistributed(address[] cids, uint256[] delegatingAmounts);
  /// @dev Emitted when the contract fails when distributing the fast finality rewards for delegators to the staking contract for delegators.
  event FastFinalityRewardDelegatorsDistributionFailed(
    address[] cids, uint256[] delegatingAmounts, uint256 contractBalance
  );

  /// @dev Emitted when the epoch is wrapped up.
  event WrappedUpEpoch(uint256 indexed periodNumber, uint256 indexed epochNumber, bool periodEnding);

  /// @dev Error of only allowed at the end of epoch
  error ErrAtEndOfEpochOnly();
  /// @dev Error of query for already wrapped up epoch
  error ErrAlreadyWrappedEpoch();

  /**
   * @dev Submits reward of the current block.
   *
   * Requirements:
   * - The method caller is coinbase.
   *
   * Emits the event `MiningRewardDeprecated` if the coinbase is slashed or no longer be a block producer.
   * Emits the event `BlockRewardSubmitted` for the valid call.
   *
   */
  function submitBlockReward() external payable;

  /**
   * @dev Receives L2 tx fee from `ZkEVMFeePlazaL1` contract.
   *
   * - L2 fee will be distributed to both `validator` and their corresponding `delegator`.
   * - L2 fee is shared among the validators and delegators based on `commissionRate`.
   *
   * Requirements:
   * - The method caller is `ZkEVMFeePlazaL1` contract.
   * @param cid The candidate id (owner) of the rollup contract.
   */
  function onL2BlockRewardSubmitted(
    address cid
  ) external payable;

  /**
   * @dev Wraps up the current epoch.
   *
   * Requirements:
   * - The method must be called when the current epoch is ending.
   * - The epoch is not wrapped yet.
   * - The method caller is coinbase.
   *
   * Emits the event `MiningRewardDistributed` when some validator has reward distributed.
   * Emits the event `StakingRewardDistributed` when some staking pool has reward distributed.
   * Emits the event `BlockProducerSetUpdated` when the epoch is wrapped up.
   * Emits the event `ValidatorSetUpdated` when the epoch is wrapped up at period ending, and the validator set gets updated.
   * Emits the event `WrappedUpEpoch`.
   *
   */
  function wrapUpEpoch() external payable;
}
