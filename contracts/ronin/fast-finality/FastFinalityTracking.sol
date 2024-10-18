// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { HasContracts } from "../../extensions/collections/HasContracts.sol";
import { IProfile } from "../../interfaces/IProfile.sol";
import { IStaking } from "../../interfaces/staking/IStaking.sol";
import { IFastFinalityTracking } from "../../interfaces/IFastFinalityTracking.sol";
import { IRoninValidatorSet } from "../../interfaces/validator/IRoninValidatorSet.sol";
import { LibArray } from "../../libraries/LibArray.sol";
import { TConsensus } from "../../udvts/Types.sol";
import { ContractType } from "../../utils/ContractType.sol";
import { ErrOncePerBlock, ErrCallerMustBeCoinbase } from "../../utils/CommonErrors.sol";

contract FastFinalityTracking is IFastFinalityTracking, Initializable, HasContracts {
  using LibArray for uint256[];

  /// @dev Mapping from epoch number => candidate id => fast finality record
  mapping(uint256 epochNumber => mapping(address cid => Record)) internal _tracker;
  /// @dev The latest block that tracked the QC vote
  uint256 internal _latestTrackingBlock;
  /// @dev Mapping from period => normalized data for staked amounts of all cids
  mapping(uint256 period => NormalizedData) internal _normalizedData;

  modifier oncePerBlock() {
    if (block.number <= _latestTrackingBlock) {
      revert ErrOncePerBlock();
    }

    _latestTrackingBlock = block.number;
    _;
  }

  modifier onlyCoinbase() {
    if (msg.sender != block.coinbase) revert ErrCallerMustBeCoinbase();
    _;
  }

  constructor() {
    _disableInitializers();
  }

  function initialize(
    address validatorContract
  ) external initializer {
    _setContract(ContractType.VALIDATOR, validatorContract);
  }

  function initializeV2(
    address profileContract
  ) external reinitializer(2) {
    _setContract(ContractType.PROFILE, profileContract);
  }

  function initializeV3(
    address stakingContract
  ) external reinitializer(3) {
    _setContract(ContractType.STAKING, stakingContract);
  }

  /**
   * @dev Getter of `_latestTrackingBlock`
   */
  function latestTrackingBlock() external view returns (uint256) {
    return _latestTrackingBlock;
  }

  /**
   * @inheritdoc IFastFinalityTracking
   */
  function getNormalizedSum(
    uint256 period
  ) external view returns (uint256 normalizedSum) {
    normalizedSum = _normalizedData[period].normalizedSum;
  }

  /**
   * @inheritdoc IFastFinalityTracking
   */
  function getNormalizedStake(uint256 period, address cid) external view returns (uint256 normalizedStake) {
    normalizedStake = _normalizedData[period].normalizedStake[cid];
  }

  /**
   * @inheritdoc IFastFinalityTracking
   */
  function recordFinality(
    TConsensus[] calldata voters
  ) external oncePerBlock onlyCoinbase {
    unchecked {
      address[] memory votedCids = __css2cidBatch(voters);

      IStaking staking = IStaking(getContract(ContractType.STAKING));
      IRoninValidatorSet validator = IRoninValidatorSet(getContract(ContractType.VALIDATOR));

      (uint256 h, uint256[] memory normalizedVoterStakeAmounts) =
        _loadOrRecordNormalizedSumAndPivot(staking, validator, votedCids);

      uint256 g = normalizedVoterStakeAmounts.sum();

      h /= 1 ether;
      g /= 1 ether;

      Record storage $record;
      uint256 length = voters.length;
      uint256 epoch = validator.epochOf(block.number);

      for (uint256 i; i < length; ++i) {
        $record = _tracker[epoch][votedCids[i]];

        ++$record.qcVoteCount;
        // Simplification of: `$record.score += (normalizedVoterStakeAmounts[i] / g) * (g * g) / (h * h)`
        $record.score += normalizedVoterStakeAmounts[i] * g / (h * h);
      }
    }
  }

  function _loadOrRecordNormalizedSumAndPivot(
    IStaking staking,
    IRoninValidatorSet validator,
    address[] memory voterCids
  ) private returns (uint256 normalizedSum_, uint256[] memory normalizedVoterStakes_) {
    uint256 currentPeriod = validator.currentPeriod();
    uint256 length = voterCids.length;
    normalizedVoterStakes_ = new uint256[](length);
    NormalizedData storage $normalizedData = _normalizedData[currentPeriod];

    if ($normalizedData.normalizedSum == 0) {
      address[] memory allCids = validator.getValidatorCandidateIds();
      uint256[] memory stakeAmounts = staking.getManyStakingTotalsById({ poolIds: allCids });
      uint256 pivot;

      (normalizedSum_, pivot) = LibArray.inplaceFindNormalizedSumAndPivot({
        cids: allCids,
        values: stakeAmounts,
        divisor: validator.maxValidatorNumber()
      });

      uint256[] memory normalizedStakeAmounts = LibArray.inplaceClip({ values: stakeAmounts, lower: 0, upper: pivot });
      for (uint256 i; i < allCids.length; ++i) {
        $normalizedData.normalizedStake[allCids[i]] = normalizedStakeAmounts[i];
      }

      $normalizedData.normalizedSum = normalizedSum_;
    } else {
      normalizedSum_ = $normalizedData.normalizedSum;
    }

    for (uint256 i; i < length; ++i) {
      normalizedVoterStakes_[i] = $normalizedData.normalizedStake[voterCids[i]];
    }
  }

  /**
   * @inheritdoc IFastFinalityTracking
   */
  function getManyFinalityVoteCounts(
    uint256 epoch,
    TConsensus[] calldata addrs
  ) external view returns (uint256[] memory voteCounts) {
    address[] memory cids = __css2cidBatch(addrs);
    return getManyFinalityVoteCountsById(epoch, cids);
  }

  /**
   * @inheritdoc IFastFinalityTracking
   */
  function getManyFinalityVoteCountsById(
    uint256 epoch,
    address[] memory cids
  ) public view returns (uint256[] memory voteCounts) {
    uint256 length = cids.length;

    voteCounts = new uint256[](length);
    for (uint i; i < length; ++i) {
      voteCounts[i] = _tracker[epoch][cids[i]].qcVoteCount;
    }
  }

  /**
   * @inheritdoc IFastFinalityTracking
   */
  function getManyFinalityScores(
    uint256 epoch,
    TConsensus[] calldata consensuses
  ) external view returns (uint256[] memory scores) {
    address[] memory cids = __css2cidBatch(consensuses);
    return getManyFinalityScoresById(epoch, cids);
  }

  /**
   * @inheritdoc IFastFinalityTracking
   */
  function getManyFinalityScoresById(
    uint256 epoch,
    address[] memory cids
  ) public view returns (uint256[] memory scores) {
    uint256 length = cids.length;
    scores = new uint256[](length);
    mapping(address => Record) storage $epochTracker = _tracker[epoch];

    for (uint256 i; i < length; ++i) {
      scores[i] = $epochTracker[cids[i]].score;
    }
  }

  function __css2cidBatch(
    TConsensus[] memory consensusAddrs
  ) internal view returns (address[] memory) {
    return IProfile(getContract(ContractType.PROFILE)).getManyConsensus2Id(consensusAddrs);
  }
}
