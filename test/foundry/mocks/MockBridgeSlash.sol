// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17 <0.9.0;

import { IBridgeSlash } from "src/interfaces/bridge/IBridgeSlash.sol";

contract MockBridgeSlash is IBridgeSlash {
  mapping(address => uint256) internal _slashMap;

  function initialize(
    address validatorContract,
    address bridgeManagerContract,
    address bridgeTrackingContract,
    address dposGA
  ) external { }
  function initializeV2() external { }

  function initializeV3(address bridgeManager, address bridgeSlash, address bridgeReward, address dposGA) external { }

  /**
   * @dev Helper for running upgrade script, required to only revoked once by the DPoS's governance admin.
   * The following must be assured after initializing REP2:
   * `_lastSyncPeriod`
   *    == `{BridgeReward}.latestRewardedPeriod + 1`
   *    == `{BridgeSlash}._startedAtPeriod - 1`
   *    == `currentPeriod()`
   */
  function initializeREP2() external { }

  function MINIMUM_VOTE_THRESHOLD() external view returns (uint256) { }

  function REMOVE_DURATION_THRESHOLD() external view returns (uint256) { }

  function TIER_1_PENALTY_DURATION() external view returns (uint256) { }

  function TIER_2_PENALTY_DURATION() external view returns (uint256) { }

  function execSlashBridgeOperators(
    address[] calldata operators,
    uint256[] calldata ballots,
    uint256 totalBallot,
    uint256 totalVote,
    uint256 period
  ) external { }

  function getAddedPeriodOf(address[] calldata bridgeOperators) external view returns (uint256[] memory addedPeriods) { }

  function getPenaltyDurations() external pure returns (uint256[] memory penaltyDurations) { }

  function getSlashTier(uint256 ballot, uint256 totalVote) external pure returns (Tier tier) { }

  function getSlashUntilPeriodOf(address[] calldata operators) external view returns (uint256[] memory untilPeriods) {
    untilPeriods = new uint256[](operators.length);
    for (uint i; i < operators.length; i++) {
      untilPeriods[i] = _slashMap[operators[i]];
    }
  }

  function cheat_setSlash(address[] calldata operators, uint256[] calldata untilPeriods) external {
    require(operators.length != untilPeriods.length, "invalid length");

    for (uint i; i < operators.length; i++) {
      _slashMap[operators[i]] = untilPeriods[i];
    }
  }
}
