// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Initializable } from "@openzeppelin-v5/contracts/proxy/utils/Initializable.sol";
import { EIP712 } from "@openzeppelin-v5/contracts/utils/cryptography/EIP712.sol";
import { SafeCast } from "@openzeppelin-v5/contracts/utils/math/SafeCast.sol";
import { EnumerableSet } from "@openzeppelin-v5/contracts/utils/structs/EnumerableSet.sol";

import { HasContracts } from "src/extensions/collections/HasContracts.sol";
import { GlobalConfigConsumer } from "src/extensions/consumers/GlobalConfigConsumer.sol";

import { IProfile } from "src/interfaces/IProfile.sol";
import { IStaking } from "src/interfaces/staking/IStaking.sol";
import { ICandidateManager } from "src/interfaces/validator/ICandidateManager.sol";

import { IBaseFeeTreasury } from "src/interfaces/basefee-treasury/IBaseFeeTreasury.sol";

import { ContractType } from "src/utils/ContractType.sol";

import { ErrEmptyArray, ErrLengthMismatch, ErrUnauthorized, RoleAccess } from "src/utils/CommonErrors.sol";

import { ErrorHandler } from "src/libraries/ErrorHandler.sol";
import { LibArray } from "src/libraries/LibArray.sol";

contract RoninBaseFeeTreasury is EIP712, Initializable, HasContracts, GlobalConfigConsumer, IBaseFeeTreasury {
  using LibArray for *;
  using SafeCast for uint256;
  using ErrorHandler for bool;
  using EnumerableSet for EnumerableSet.Bytes32Set;

  uint256 public constant COOLDOWN_PERIOD = 1 days;
  uint256 public constant MIN_PROPOSAL_DURATION = 1 days;
  bytes32 internal constant _TYPE_HASH = keccak256(
    "Proposal(address proposer,uint32 nonce,uint40 expiry,address executor,address[] recipients,uint96[] amounts,bytes[] callDatas)"
  );

  uint256[50] private __gap;

  /// @dev Global nonce for proposals.
  uint32 internal _globalNonce;
  /// @dev Threshold for passing proposals.
  Threshold internal _threshold;
  /// @dev Pending proposal set.
  EnumerableSet.Bytes32Set internal _pendingProposals;
  /// @dev Mapping from hash to proposal info.
  mapping(bytes32 hash => ProposalInfo) internal _info;

  modifier onlyCandidateAdmin(
    address cid
  ) {
    _requireCandidateAdmin(cid);
    _;
  }

  modifier onlyState(bytes32 hash, State state) {
    _requireState(hash, state);
    _;
  }

  modifier syncPendingProposals() {
    _syncPendingProposals();
    _;
  }

  constructor() EIP712(type(RoninBaseFeeTreasury).name, "1") {
    _disableInitializers();
  }

  function initialize(
    address profile,
    address staking,
    address validatorSet,
    uint8 num,
    uint8 denom
  ) external initializer {
    _setThreshold(num, denom);
    _setContract(ContractType.PROFILE, profile);
    _setContract(ContractType.STAKING, staking);
    _setContract(ContractType.VALIDATOR, validatorSet);
  }

  /**
   * @inheritdoc IBaseFeeTreasury
   */
  function setThreshold(uint8 num, uint8 denom) external onlyAdmin syncPendingProposals {
    _setThreshold(num, denom);
  }

  /**
   * @inheritdoc IBaseFeeTreasury
   */
  function incrementNonce() external onlyAdmin syncPendingProposals {
    _incrementNonce();
  }

  /**
   * @inheritdoc IBaseFeeTreasury
   */
  function vote(
    address cid,
    bytes32 hash,
    Vote v
  ) external onlyCandidateAdmin(cid) onlyState(hash, State.Active) syncPendingProposals {
    _vote(hash, cid, v);
    _tryExecute(hash);
  }

  /**
   * @inheritdoc IBaseFeeTreasury
   */
  function propose(
    Proposal calldata proposal
  ) external onlyCandidateAdmin(proposal.proposer) syncPendingProposals returns (bytes32 hash) {
    validateProposal(proposal);

    hash = hashProposal(proposal);

    _requireState(hash, State.Unknown);

    _createProposal(hash, proposal, _snapshotVotePower(hash));
    _vote(hash, proposal.proposer, Vote.For);
    _tryExecute(hash);
  }

  /**
   * @inheritdoc IBaseFeeTreasury
   */
  function cancel(
    bytes32 hash
  ) external onlyCandidateAdmin(_info[hash]._proposal.proposer) onlyState(hash, State.Active) syncPendingProposals {
    ProposalInfo storage $ = _info[hash];

    require(_pendingProposals.remove(hash), ErrInexistentProposal(hash));

    $._state = State.Cancelled;

    emit ProposalCancelled(msg.sender, hash);
  }

  /**
   * @inheritdoc IBaseFeeTreasury
   */
  function execute(
    bytes32 hash
  ) external onlyState(hash, State.Passed) syncPendingProposals {
    require(_info[hash]._proposal.executor == msg.sender, ErrInvalidExecutor(msg.sender));
    require(_tryExecute(hash), ErrCannotExecuteProposal(hash));
  }

  /**
   * @inheritdoc IBaseFeeTreasury
   */
  function validateProposal(
    Proposal calldata p
  ) public view {
    _requireValidNonce(p.nonce);
    require(p.executor != address(0), ErrInvalidExecutor(p.executor));
    require(
      p.expiry >= block.timestamp + MIN_PROPOSAL_DURATION,
      ErrExpiryDurationTooShort(block.timestamp + MIN_PROPOSAL_DURATION, p.expiry)
    );

    address[] calldata recipients = p.recipients;

    uint256 length = recipients.length;
    require(length != 0, ErrEmptyArray());
    require(length == p.amounts.length && length == p.callDatas.length, ErrLengthMismatch(msg.sig));

    for (uint256 i; i < length; ++i) {
      require(p.amounts[i] != 0, ErrZeroAmount(i));
      require(recipients[i] != address(0) && recipients[i] != address(this), ErrInvalidRecipient(i, recipients[i]));
    }
  }

  /**
   * @inheritdoc IBaseFeeTreasury
   */
  function getThreshold() external view returns (Threshold memory threshold) {
    return _threshold;
  }

  /**
   * @inheritdoc IBaseFeeTreasury
   */
  function getState(
    bytes32 hash
  ) public view returns (State s) {
    ProposalInfo storage $ = _info[hash];
    s = $._state;
    Proposal storage $p = $._proposal;

    if ((s == State.Active || s == State.Passed) && ($p.expiry < block.timestamp || $p.nonce != getGlobalNonce())) {
      s = State.Deprecated;
    }
  }

  /**
   * @inheritdoc IBaseFeeTreasury
   */
  function hashProposal(
    Proposal calldata proposal
  ) public view returns (bytes32) {
    bytes32[] memory calldataHashList = new bytes32[](proposal.callDatas.length);

    for (uint256 i; i < calldataHashList.length; ++i) {
      calldataHashList[i] = keccak256(proposal.callDatas[i]);
    }

    return _hashTypedDataV4(
      keccak256(
        abi.encode(
          _TYPE_HASH,
          proposal.proposer,
          proposal.nonce,
          proposal.expiry,
          proposal.executor,
          proposal.recipients.hash(),
          proposal.amounts.hash(),
          calldataHashList.hash()
        )
      )
    );
  }

  /**
   * @inheritdoc IBaseFeeTreasury
   */
  function getGlobalNonce() public view returns (uint32 globalNonce) {
    return _globalNonce;
  }

  /**
   * @inheritdoc IBaseFeeTreasury
   */
  function getProposal(
    bytes32 hash
  ) external view returns (Proposal memory proposal) {
    return _info[hash]._proposal;
  }

  /**
   * @inheritdoc IBaseFeeTreasury
   */
  function getProposalCreatedAt(
    bytes32 hash
  ) external view returns (uint40 createdAt) {
    return _info[hash]._createdAt;
  }

  /**
   * @inheritdoc IBaseFeeTreasury
   */
  function getCurrentVotePower(
    bytes32 hash
  ) external view returns (VotePower memory votePow) {
    return _info[hash]._votePow;
  }

  /**
   * @inheritdoc IBaseFeeTreasury
   */
  function getSnapshotTotalVotePower(
    bytes32 hash
  ) external view returns (uint256 totalVotePower) {
    return _info[hash]._totalVotePow;
  }

  /**
   * @inheritdoc IBaseFeeTreasury
   */
  function getVote(bytes32 hash, address cid) external view returns (Vote v) {
    return _info[hash]._vote[cid];
  }

  /**
   * @inheritdoc IBaseFeeTreasury
   */
  function getPendingProposals() external view returns (bytes32[] memory pendingHashes) {
    bytes32[] memory allHashes = _pendingProposals.values();
    uint256 length = allHashes.length;

    uint256 count;
    pendingHashes = new bytes32[](length);

    for (uint256 i; i < length; ++i) {
      if (getState(allHashes[i]) == State.Active) {
        pendingHashes[count] = allHashes[i];
        ++count;
      }
    }

    assembly ("memory-safe") {
      mstore(pendingHashes, count)
    }
  }

  /**
   * @inheritdoc IBaseFeeTreasury
   */
  function getSnapshotVotePowerById(bytes32 hash, address cid) external view returns (uint256 votePower) {
    return _info[hash]._votePower[cid];
  }

  /**
   * @inheritdoc IBaseFeeTreasury
   */
  function getMinimumVotePowerToPass(
    bytes32 hash
  ) external view returns (uint256 votePower) {
    return _calcMinVoteFor(_info[hash]._totalVotePow);
  }

  /**
   * @inheritdoc IBaseFeeTreasury
   */
  function getMinimumVotePowerToCancel(
    bytes32 hash
  ) external view returns (uint256 minVoteAgainst) {
    return _calcMinVoteAgainst(_info[hash]._totalVotePow);
  }

  /**
   * @dev Create a new proposal.
   */
  function _createProposal(bytes32 hash, Proposal memory p, uint256 totalVotePower) internal {
    ProposalInfo storage $ = _info[hash];

    $._createdAt = uint40(block.timestamp);
    $._state = State.Active;
    $._proposal = p;
    $._totalVotePow = (totalVotePower).toUint96();

    require(_pendingProposals.add(hash), ErrExistedProposal(hash));

    emit ProposalCreated(msg.sender, p.proposer, hash, p, $._createdAt);
  }

  /**
   * @dev Snapshot the vote power of all candidates at the time of proposal creation.
   */
  function _snapshotVotePower(
    bytes32 hash
  ) internal returns (uint256 totalVotePower) {
    address[] memory allCids = ICandidateManager(getContract(ContractType.VALIDATOR)).getValidatorCandidateIds();
    uint256[] memory selfStakes = IStaking(getContract(ContractType.STAKING)).getManySelfStakingsById(allCids);

    uint256 length = allCids.length;
    require(length == selfStakes.length, ErrLengthMismatch(msg.sig));

    ProposalInfo storage $ = _info[hash];

    for (uint256 i; i < length; ++i) {
      uint96 scaledStake = (selfStakes[i] / 1 ether).toUint96();
      totalVotePower += scaledStake;

      $._votePower[allCids[i]] = scaledStake;

      // Self-stake is expected to > 1e18
      require(scaledStake != 0, ErrPanicDataCorruption(allCids[i]));
    }
  }

  /**
   * @dev Vote on a proposal.
   */
  function _vote(bytes32 hash, address cid, Vote v) internal {
    ProposalInfo storage $ = _info[hash];
    IProfile profile = IProfile(getContract(ContractType.PROFILE));

    _requireValidNonce($._proposal.nonce);
    require(v == Vote.For || v == Vote.Against, ErrInvalidVote());
    require($._votePower[cid] != 0, ErrNewlyRegisteredOrRenouncedOrEmergencyExit());
    require($._vote[cid] == Vote.Unknown, ErrAlreadyVoted(hash, cid, $._vote[cid]));
    require(
      _computePeriod(profile.getId2RegisteredAt(cid) + COOLDOWN_PERIOD) <= _computePeriod($._createdAt),
      ErrNewlyRegisteredCannotVote(cid)
    );

    $._vote[cid] = v;
    if (v == Vote.For) {
      $._votePow.vFor += $._votePower[cid];
    } else {
      $._votePow.vAgainst += $._votePower[cid];
    }

    emit Voted(msg.sender, cid, hash, v, $._votePower[cid]);
  }

  /**
   * @dev Try to execute a proposal.
   *
   * - Skip if the proposal is not passed.
   * - Skip if the proposal is not executed by the contract itself or `msg.sender`.
   * - Skip if the proposal is cancelled.
   * - Remove the proposal from the pending set if transitioned to `Passed` or `Cancelled` or `Executed`.
   *
   * Emits a {ProposalCancelled} event if the proposal is cancelled.
   * Emits a {ProposalPassed} event if the proposal is passed (current caller is not executor).
   * Emits a {ProposalExecuted} event if the proposal is executed
   *
   * @return executed true if the proposal is executed.
   */
  function _tryExecute(
    bytes32 hash
  ) internal returns (bool executed) {
    ProposalInfo storage $ = _info[hash];

    if ($._votePow.vAgainst > _calcMinVoteAgainst($._totalVotePow)) {
      $._state = State.Cancelled;
      emit ProposalCancelled(msg.sender, hash);
      return false;
    }

    if ($._votePow.vFor < _calcMinVoteFor($._totalVotePow)) return false;

    // Removal can be skipped if it's already removed when proposal is passed by voting but not automatically executed.
    _pendingProposals.remove(hash);

    Proposal storage $p = $._proposal;

    // Skip executing if `executor` is not the contract itself or `msg.sender`.
    if (!($p.executor == address(this) || $p.executor == msg.sender)) {
      $._state = State.Passed;
      emit ProposalPassed(msg.sender, hash);
      return false;
    }

    uint256 length = $p.recipients.length;

    for (uint256 i; i < length; ++i) {
      (bool success, bytes memory ret) = $p.recipients[i].call{ value: $p.amounts[i] }($p.callDatas[i]);
      success.handleRevert(bytes4($p.callDatas[i]), ret);
    }

    $._state = State.Executed;

    emit ProposalExecuted(msg.sender, hash);

    return true;
  }

  /**
   * @dev Set the threshold for passing proposals.
   *
   * - Increment the global nonce.
   *
   * Emits a {GlobalNonceUpdated} event.
   * Emits a {ThresholdUpdated} event.
   */
  function _setThreshold(uint8 num, uint8 denom) internal {
    _incrementNonce();

    require(!(denom == 0 || num == 0 || num >= denom), ErrInvalidThreshold(num, denom));

    _threshold = Threshold(num, denom);

    emit ThresholdUpdated(msg.sender, num, denom);
  }

  /**
   * @dev Increment the global nonce.
   *
   * Emits a {GlobalNonceUpdated} event.
   */
  function _incrementNonce() internal {
    ++_globalNonce;
    emit GlobalNonceUpdated(msg.sender, getGlobalNonce());
  }

  /**
   * @dev Try to remove the pending proposals.
   */
  function _syncPendingProposals() internal {
    uint256 length = _pendingProposals.length();
    bytes32[] memory pendingProposals = _pendingProposals.values();

    for (uint256 i; i < length; ++i) {
      if (getState(pendingProposals[i]) != State.Active) {
        _pendingProposals.remove(pendingProposals[i]);
      }
    }
  }

  /**
   * @dev Calculate the minimum vote power required for a proposal to pass.
   */
  function _calcMinVoteFor(
    uint256 totalVotePower
  ) internal view returns (uint96 minVoteFor) {
    minVoteFor = (totalVotePower - _calcMinVoteAgainst(totalVotePower)).toUint96();
    require(minVoteFor != 0, ErrZeroMinVotePower());
  }

  /**
   * @dev Calculate the minimum vote power required for a proposal to cancel.
   */
  function _calcMinVoteAgainst(
    uint256 totalVotePower
  ) internal view returns (uint96 minVoteAgainst) {
    minVoteAgainst = (totalVotePower * (_threshold.denom - _threshold.num) / _threshold.denom).toUint96();
    require(minVoteAgainst != 0, ErrZeroMinVotePower());
  }

  /**
   * @dev Require the proposal nonce to be equal to the global nonce.
   */
  function _requireValidNonce(
    uint256 nonce
  ) internal view {
    require(nonce == getGlobalNonce(), ErrInvalidNonce(getGlobalNonce(), nonce));
  }

  /**
   * @dev Require the proposal state to be equal to the required state.
   */
  function _requireState(bytes32 hash, State requiredState) internal view {
    State currState = getState(hash);
    require(currState == requiredState, ErrRequiredStateNotReached(hash, requiredState, currState));
  }

  /**
   * @dev Require the candidate to be an admin.
   * The candidate must not be revoked.
   */
  function _requireCandidateAdmin(
    address cid
  ) internal view {
    require(
      IProfile(getContract(ContractType.PROFILE)).getId2Admin(cid) == msg.sender
        && ICandidateManager(getContract(ContractType.VALIDATOR)).getCandidateInfoById(cid).revokingTimestamp == 0,
      ErrUnauthorized(msg.sig, RoleAccess.CANDIDATE_ADMIN)
    );
  }

  /**
   * @dev See {TimingStorage-_computePeriod}.
   *
   * This duplicates the implementation in {RoninValidatorSet-_computePeriod} to reduce external calls.
   */
  function _computePeriod(
    uint256 timestamp
  ) internal pure returns (uint256) {
    return timestamp / PERIOD_DURATION;
  }
}
