// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { IRoninValidatorSet } from "../../interfaces/validator/IRoninValidatorSet.sol";
import { IFastFinalityTracking } from "../../interfaces/IFastFinalityTracking.sol";
import "../../interfaces/IProfile.sol";
import "../../extensions/collections/HasContracts.sol";
import "../../utils/CommonErrors.sol";

contract FastFinalityTracking is IFastFinalityTracking, Initializable, HasContracts {
  /// @dev Mapping from epoch number => candidate id => number of QC vote
  mapping(uint256 epochNumber => mapping(address cid => uint256 qcVoteCount)) internal _tracker;
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

  /**
   * @dev Getter of `_latestTrackingBlock`
   */
  function latestTrackingBlock() external view returns (uint256) {
    return _latestTrackingBlock;
  }

  /**
   * @inheritdoc IFastFinalityTracking
   */
  function recordFinality(TConsensus[] calldata voters) external override oncePerBlock onlyCoinbase {
    uint256 currentEpoch = IRoninValidatorSet(getContract(ContractType.VALIDATOR)).epochOf(block.number);
    address[] memory cids = __css2cidBatch(voters);

    for (uint i; i < cids.length; ++i) {
      ++_tracker[currentEpoch][cids[i]];
    }
  }

  /**
   * @inheritdoc IFastFinalityTracking
   */
  function getManyFinalityVoteCounts(
    uint256 epoch,
    TConsensus[] calldata addrs
  ) external view override returns (uint256[] memory voteCounts) {
    address[] memory cids = __css2cidBatch(addrs);
    return getManyFinalityVoteCountsById(epoch, cids);
  }

  /**
   * @inheritdoc IFastFinalityTracking
   */
  function getManyFinalityVoteCountsById(
    uint256 epoch,
    address[] memory cids
  ) public view override returns (uint256[] memory voteCounts) {
    uint256 length = cids.length;

    voteCounts = new uint256[](length);
    for (uint i; i < length; ++i) {
      voteCounts[i] = _tracker[epoch][cids[i]];
    }
  }

  function __css2cidBatch(TConsensus[] memory consensusAddrs) internal view returns (address[] memory) {
    return IProfile(getContract(ContractType.PROFILE)).getManyConsensus2Id(consensusAddrs);
  }
}
