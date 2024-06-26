// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { GlobalConfigConsumer } from "../../../extensions/consumers/GlobalConfigConsumer.sol";
import { ITimingInfo } from "../../../interfaces/validator/info-fragments/ITimingInfo.sol";

abstract contract TimingStorage is ITimingInfo, GlobalConfigConsumer {
  /// @dev The number of blocks in a epoch
  uint256 internal _numberOfBlocksInEpoch;
  /// @dev The last updated block
  uint256 internal _lastUpdatedBlock;
  /// @dev The last updated period
  uint256 internal _lastUpdatedPeriod;
  /// @dev The starting block of the last updated period
  uint256 internal _currentPeriodStartAtBlock;

  /// @dev Mapping from epoch index => period index
  mapping(uint256 epoch => uint256 period) internal _periodOf;
  /// @dev Mapping from period index => ending block
  mapping(uint256 period => uint256 endedAtBlock) internal _periodEndBlock;
  /// @dev The first period which tracked period ending block
  uint256 internal _firstTrackedPeriodEnd;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[47] private ______gap;

  /**
   * @inheritdoc ITimingInfo
   */
  function getPeriodEndBlock(uint256 period) external view returns (uint256 endedAtBlock) {
    if (period > _lastUpdatedPeriod) revert ErrPeriodNotEndedYet(period);
    uint256 firstTrackedPeriodEnd = _firstTrackedPeriodEnd;
    if (period < firstTrackedPeriodEnd) revert ErrPeriodEndingBlockNotTracked(period, firstTrackedPeriodEnd);

    endedAtBlock = _periodEndBlock[period];
  }

  /**
   * @inheritdoc ITimingInfo
   */
  function getLastUpdatedBlock() external view override returns (uint256) {
    return _lastUpdatedBlock;
  }

  /**
   * @inheritdoc ITimingInfo
   */
  function epochOf(uint256 _block) public view virtual override returns (uint256) {
    return _block / _numberOfBlocksInEpoch + 1;
  }

  /**
   * @inheritdoc ITimingInfo
   */
  function tryGetPeriodOfEpoch(uint256 _epoch) external view returns (bool _filled, uint256 _periodNumber) {
    return (_epoch <= epochOf(block.number) || _periodOf[_epoch] > 0, _periodOf[_epoch]);
  }

  /**
   * @inheritdoc ITimingInfo
   */
  function isPeriodEnding() external view override returns (bool) {
    return _isPeriodEnding(_computePeriod(block.timestamp));
  }

  /**
   * @inheritdoc ITimingInfo
   */
  function epochEndingAt(uint256 _block) public view virtual override returns (bool) {
    return _block % _numberOfBlocksInEpoch == _numberOfBlocksInEpoch - 1;
  }

  /**
   * @inheritdoc ITimingInfo
   */
  function currentPeriod() public view virtual override returns (uint256) {
    return _lastUpdatedPeriod;
  }

  /**
   * @inheritdoc ITimingInfo
   */
  function currentPeriodStartAtBlock() public view override returns (uint256) {
    return _currentPeriodStartAtBlock;
  }

  /**
   * @inheritdoc ITimingInfo
   */
  function numberOfBlocksInEpoch() public view virtual override returns (uint256 _numberOfBlocks) {
    return _numberOfBlocksInEpoch;
  }

  /**
   * @dev See `ITimingInfo-isPeriodEnding`
   */
  function _isPeriodEnding(uint256 _newPeriod) internal view virtual returns (bool) {
    return _newPeriod > _lastUpdatedPeriod;
  }

  /**
   * @dev Returns the calculated period.
   */
  function _computePeriod(uint256 _timestamp) internal pure returns (uint256) {
    return _timestamp / PERIOD_DURATION;
  }
}
