// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17 <0.9.0;

import { TConsensus } from "src/udvts/Types.sol";

contract MockValidatorSet {
  struct ValidatorCandidate {
    /**
     * @dev The address of the candidate admin.
     * @custom shadowed-storage This storage slot is always kept in sync with {Profile-CandidateProfile}.admin.
     */
    address __shadowedAdmin;
    /**
     * @dev Address of the validator that produces block, e.g. block.coinbase. This is so-called validator address.
     * @custom shadowed-storage This storage slot is always kept in sync with {Profile-CandidateProfile}.consensus.
     */
    TConsensus __shadowedConsensus;
    /**
     * @dev Address that receives mining reward of the validator
     * @custom shadowed-storage This storage slot is always kept in sync with {Profile-CandidateProfile}.treasury.
     */
    address payable __shadowedTreasury;
    /// @dev Address of the bridge operator corresponding to the candidate
    address ____deprecatedBridgeOperatorAddr;
    /**
     * @dev The percentage of reward that validators can be received, the rest goes to the delegators.
     * Values in range [0; 100_00] stands for 0-100%
     */
    uint256 commissionRate;
    /// @dev The timestamp that scheduled to revoke the candidate (no schedule=0)
    uint256 revokingTimestamp;
    /// @dev The deadline that the candidate must top up staking amount to keep it larger than or equal to the threshold (no deadline=0)
    uint256 topupDeadline;
  }

  uint256 private _period;
  mapping(address id => ValidatorCandidate) private _candidate;

  function setPeriod(
    uint256 period
  ) external {
    _period = period;
  }

  function currentPeriod() external view returns (uint256) {
    return _period;
  }

  function getValidatorCandidates() external pure returns (address[] memory) {
    return new address[](0);
  }

  function isCandidateAdmin(TConsensus, /*consensus*/ address /*admin*/ ) external pure returns (bool) {
    return true;
  }

  function isCandidateAdminById(address, /*cid*/ address /*admin*/ ) external pure returns (bool) {
    return true;
  }

  function getCandidateInfoById(
    address id
  ) external view returns (ValidatorCandidate memory validatorCandidate) {
    return _candidate[id];
  }

  function exposed_setValidatorCandidate(address id, ValidatorCandidate memory candidate) external {
    _candidate[id] = candidate;
  }

  function exposed_setRenounceStatus(address id, uint256 revokingTimestamp) external {
    _candidate[id].revokingTimestamp = revokingTimestamp;
  }
}
