// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { TConsensus } from "../udvts/Types.sol";

interface IFastFinalityTracking {
  struct Record {
    // The number of votes for fast finality.
    uint256 qcVoteCount;
    // The fast finality score.
    uint256 score;
  }

  // See {findNormalizedSumAndPivot}
  struct NormalizedData {
    uint256 normalizedSum;
    mapping(address cid => uint256 normalizedStake) normalizedStake;
  }

  function initialize(address validatorContract) external;

  function initializeV2(address profileContract) external;

  function initializeV3(address stakingContract) external;

  /**
   * @dev Submit list of `voters` who vote for fast finality in the current block.
   *
   * Requirements:
   * - Only called once per block
   * - Only coinbase can call this method
   */
  function recordFinality(TConsensus[] calldata voters) external;

  /**
   * @dev Returns vote count of `addrs` in the `epoch`.
   */
  function getManyFinalityVoteCounts(
    uint256 epoch,
    TConsensus[] calldata addrs
  ) external view returns (uint256[] memory voteCounts);

  /**
   * @dev Returns normalized data for given period.
   */
  function getNormalizedSum(uint256 period) external view returns (uint256 normalizedSum);

  /**
   * @dev Returns normalized stake of `cid` in the `period`.
   */
  function getNormalizedStake(uint256 period, address cid) external view returns (uint256 normalizedStake);

  /**
   * @dev Returns vote count of `consensuses` in the `epoch`.
   */
  function getManyFinalityScores(
    uint256 epoch,
    TConsensus[] calldata consensuses
  ) external view returns (uint256[] memory voteCounts);

  /**
   * @dev Returns vote count of `addrs` in the `epoch`.
   */
  function getManyFinalityScoresById(
    uint256 epoch,
    address[] calldata cids
  ) external view returns (uint256[] memory voteCounts);

  /**
   * @dev Returns vote count of `cids` in the `epoch`.
   */
  function getManyFinalityVoteCountsById(
    uint256 epoch,
    address[] calldata cids
  ) external view returns (uint256[] memory voteCounts);
}
