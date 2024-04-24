// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { HasContracts } from "../../extensions/collections/HasContracts.sol";
import { IProfile } from "../../interfaces/IProfile.sol";
import { IStaking } from "../../interfaces/staking/IStaking.sol";
import { ICandidateManager } from "../../interfaces/validator/ICandidateManager.sol";
import { IFastFinalityTracking } from "../../interfaces/IFastFinalityTracking.sol";
import { RoninValidatorSet } from "../../ronin/validator/RoninValidatorSet.sol";
import { LibArray } from "../../libraries/LibArray.sol";
import { TConsensus } from "../../udvts/Types.sol";
import { ContractType } from "../../utils/ContractType.sol";
import { ErrOncePerBlock, ErrCallerMustBeCoinbase } from "../../utils/CommonErrors.sol";

contract FastFinalityTracking is IFastFinalityTracking, Initializable, HasContracts {
  using LibArray for *;

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

  function initialize(address validatorContract) external initializer {
    _setContract(ContractType.VALIDATOR, validatorContract);
  }

  function initializeV2(address profileContract) external reinitializer(2) {
    _setContract(ContractType.PROFILE, profileContract);
  }

  function initializeV3(address stakingContract) external reinitializer(3) {
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
  function recordFinality(TConsensus[] calldata voters) external oncePerBlock onlyCoinbase {
    {
      unchecked {
        address[] memory votedCids = __css2cidBatch(voters);

        IStaking staking = IStaking(getContract(ContractType.STAKING));
        RoninValidatorSet validator = RoninValidatorSet(getContract(ContractType.VALIDATOR));

        (uint256 h, uint256 upper) = _loadOrRecordNormalizedSumAndUpperBound(staking, validator);
        uint256[] memory normalizedVotedStakeAmounts =
          LibArray.inplaceClip({ values: staking.getManyStakingTotalsById(votedCids), lower: 0, upper: upper });
        uint256 g = normalizedVotedStakeAmounts.sum();

        h /= 1 ether;
        g /= 1 ether;

        Record storage $record;
        uint256 length = voters.length;
        uint256 epoch = validator.epochOf(block.number);

        for (uint256 i; i < length; ++i) {
          $record = _tracker[epoch][votedCids[i]];

          ++$record.qcVoteCount;
          $record.score += normalizedVotedStakeAmounts[i] * (g * g) / (h * h);
        }
      }
    }
  }

  function _loadOrRecordNormalizedSumAndUpperBound(
    IStaking staking,
    RoninValidatorSet validator
  ) private returns (uint256 normalizedSum, uint256 upperBound) {
    uint256 currentPeriod = validator.currentPeriod();
    NormalizedData storage $normalizedData = _normalizedData[currentPeriod];

    if ($normalizedData.upperBound == 0) {
      (normalizedSum, upperBound) = LibArray.findNormalizedSumAndUpperBound({
        values: staking.getManyStakingTotalsById({ poolIds: validator.getValidatorCandidateIds() }),
        divisor: validator.maxValidatorNumber()
      });

      $normalizedData.upperBound = upperBound;
      $normalizedData.normalizedSum = normalizedSum;
    } else {
      normalizedSum = $normalizedData.normalizedSum;
      upperBound = $normalizedData.upperBound;
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
  function getManyFinalityScoresById(
    uint256 epoch,
    address[] calldata cids
  ) external view returns (uint256[] memory scores) {
    uint256 length = cids.length;
    scores = new uint256[](length);
    mapping(address => Record) storage $epochTracker = _tracker[epoch];

    for (uint256 i; i < length; ++i) {
      scores[i] = $epochTracker[cids[i]].score;
    }
  }

  function __css2cidBatch(TConsensus[] memory consensusAddrs) internal view returns (address[] memory) {
    return IProfile(getContract(ContractType.PROFILE)).getManyConsensus2Id(consensusAddrs);
  }
}
