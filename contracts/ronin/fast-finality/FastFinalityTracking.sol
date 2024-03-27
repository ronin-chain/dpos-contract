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
        uint256 h;
        uint256 g;
        uint256 upper;
        uint256 epoch;

        uint256[] memory votedStakeds;
        address[] memory votedCids = __css2cidBatch(voters);

        Record storage $record;
        {
          IStaking staking = IStaking(getContract(ContractType.STAKING));
          RoninValidatorSet validator = RoninValidatorSet(getContract(ContractType.VALIDATOR));

          epoch = validator.epochOf(block.number);
          votedStakeds = staking.getManyStakingTotalsById(votedCids);

          g = votedStakeds.sum() / 1 ether;
          upper = g / validator.maxValidatorNumber();
          h = staking.getManyStakingTotalsById(validator.getValidatorCandidateIds()).sum() / 1 ether;
        }

        for (uint256 i; i < voters.length; ++i) {
          $record = _tracker[epoch][votedCids[i]];

          $record.qcVoteCount++;
          // bound to range [staked, 1/22 of total staked]
          $record.score += Math.min(upper, votedStakeds[i]) * g / h;
        }
      }
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
