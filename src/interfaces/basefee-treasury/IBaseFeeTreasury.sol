// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IBaseFeeTreasury {
  struct Proposal {
    // The address of the cid.
    address proposer;
    // The nonce of the proposal. Must match with the global nonce in order to execute the proposal.
    uint32 nonce;
    // The expiry timestamp of the proposal.
    uint40 expiry;
    // The address of the executor.
    address executor;
    // The list of recipients.
    address[] recipients;
    // The list of amounts.
    uint96[] amounts;
    // The list of call datas.
    bytes[] callDatas;
  }

  struct VotePower {
    // The total vote power for.
    uint96 vFor;
    // The total vote power against.
    uint96 vAgainst;
  }

  struct ProposalInfo {
    // The timestamp when the proposal is created.
    uint40 _createdAt;
    // The total vote power for the proposal.
    uint96 _totalVotePow;
    // The current accumulating vote power (For and Against).
    VotePower _votePow;
    // The current state of the proposal.
    State _state;
    // The proposal data.
    Proposal _proposal;
    // Mapping of candidate id to vote side.
    mapping(address cid => Vote vote) _vote;
    // Mapping of candidate id to snapshot vote power.
    mapping(address cid => uint96 votePower) _votePower;
  }

  enum Vote {
    Unknown,
    For,
    Against
  }

  enum State {
    // Proposal hash not found
    Unknown,
    // Proposal is proposed and waiting for voting
    Active,
    // Proposal is passed and waiting for execution
    Passed,
    // Proposal is executed
    Executed,
    // Proposal is cancelled (either cancelled by proposer or expired, or voted against)
    Cancelled,
    // Proposal is executed but reverted or passed expiry but not enough voting power
    Deprecated
  }

  struct Threshold {
    uint8 num;
    uint8 denom;
  }

  /// @dev Revert if failed to execute proposal.
  error ErrCannotExecuteProposal(bytes32 hash);
  /// @dev Revert if required state is not match.
  error ErrRequiredStateNotReached(bytes32 hash, State requiredState, State currentState);
  /// @dev Revert if proposal is not existed.
  error ErrInexistentProposal(bytes32 hash);
  /// @dev Revert if proposal is already existed.
  error ErrExistedProposal(bytes32 hash);
  /// @dev Revert if minimum vote weight is zero.
  error ErrZeroMinVotePower();
  /// @dev Revert if given index in `amounts` array is zero.
  error ErrZeroAmount(uint256 idx);
  /// @dev Revert if given index in `recipients` array is zero.
  error ErrInvalidRecipient(uint256 idx, address recipient);
  /// @dev Revert if candidate admin is newly registered or renounced or emergency exit.
  error ErrNewlyRegisteredOrRenouncedOrEmergencyExit();
  /// @dev Revert if executor is address(0).
  error ErrInvalidExecutor(address executor);
  /// @dev Revert if vote is Unknown.
  error ErrInvalidVote();
  /// @dev Revert if candidate admin already voted for given hash.
  error ErrAlreadyVoted(bytes32 hash, address cid, Vote vote);
  /// @dev Revert if candidate's self-stake is invalid.
  error ErrPanicDataCorruption(address cid);
  /// @dev Revert if `num` is greater than `denom` or `num` is zero or `denom` is zero.
  error ErrInvalidThreshold(uint8 num, uint8 denom);
  /// @dev Revert if expiry duration is too short.
  error ErrExpiryDurationTooShort(uint256 minExpectedExpiry, uint256 providedExpiry);
  /// @dev Revert if nonce is invalid.
  error ErrInvalidNonce(uint256 expected, uint256 got);
  /// @dev Revert if candidate admin is newly registered.
  error ErrNewlyRegisteredCannotVote(address cid);

  /// @dev Emitted when global nonce updated.
  event GlobalNonceUpdated(address indexed by, uint256 nonce);
  /// @dev Emitted when a candidate voted.
  event Voted(address indexed by, address indexed cid, bytes32 indexed hash, Vote vote, uint256 voteWeight);
  /// @dev Emitted when a proposal is cancelled.
  event ProposalCancelled(address indexed by, bytes32 indexed hash);
  /// @dev Emitted when a proposal is passed.
  event ProposalPassed(address indexed by, bytes32 indexed hash);
  /// @dev Emitted when a proposal is executed.
  event ProposalExecuted(address indexed by, bytes32 indexed hash);
  /// @dev Emitted when a proposal is created.
  event ProposalCreated(
    address indexed by, address indexed cid, bytes32 indexed hash, Proposal proposal, uint40 createdAt
  );
  /// @dev Emitted when threshold updated.
  event ThresholdUpdated(address indexed by, uint8 num, uint8 denom);

  function initialize(address profile, address staking, address validatorSet, uint8 num, uint8 denom) external;

  /**
   * @dev Set the threshold for the proposal to pass.
   *
   * - Global nonce will be increased by one.
   *
   * Requirements:
   * - `msg.sender` is `RoninGovernanceAdmin`.
   * - `num` must be less than to `denom`.
   * - `num` can not be zero.
   * - `denom` must be greater than zero.
   *
   * Emits a {GlobalNonceUpdated} event.
   * Emits a {ThresholdUpdated} event.
   */
  function setThreshold(uint8 num, uint8 denom) external;

  /**
   * @dev Increment the global nonce.
   *
   * Requirements:
   * - `msg.sender` must be `RoninGovernanceAdmin`.
   */
  function incrementNonce() external;

  /**
   * @dev Propose a new proposal.
   *
   * - Automatically vote for candidate admin.
   *
   * Requirements:
   * - `msg.sender` must be `validator candidate admin`.
   * - `proposal.proposer` must be `candidate id`.
   * - `proposal.expiry` must be greater than or equal to the current block timestamp + `MIN_PROPOSAL_DURATION`.
   * - `proposal.recipients`, `proposal.amounts`, and `proposal.callDatas` must have the same length.
   * - `proposal.executor` must either be valid address or `address(this)`.
   * - `proposal.amounts` must not contain zero.
   * - `proposal.recipients` must not contain zero address or dead address.
   * - `hash` must not be duplicated.
   */
  function propose(
    Proposal calldata proposal
  ) external returns (bytes32 hash);

  /**
   * @dev Cancel a proposal.
   *
   * Requirements:
   * - `msg.sender` must be candidate admin of the proposal.
   * - `hash` must be existed and not executed (ProposalStatus must either be Active or Passed).
   */
  function cancel(
    bytes32 hash
  ) external;

  /**
   * @dev Vote for a proposal.
   *
   * Requirements:
   * - `msg.sender` must be `validator candidate admin`.
   * - `msg.sender` registered timestamp must be < proposal creation timestamp.
   * - `msg.sender` must not voted for the proposal before.
   * - `hash` must be existed and not executed (ProposalStatus must either be Active or Passed).
   * - `vote` must be either be `For` or `Against`.
   * - `proposal.nonce` must be equal to `globalNonce`.
   */
  function vote(address cid, bytes32 hash, Vote v) external;

  /**
   * @dev Execute a proposal.
   *
   * Requirements:
   * - `msg.sender` must be `proposal.executor`.
   * - `hash` must be existed and passed (ProposalStatus must be Passed).
   */
  function execute(
    bytes32 hash
  ) external;

  /**
   * @dev Get the minimum proposal duration (1 days).
   */
  function MIN_PROPOSAL_DURATION() external view returns (uint256);

  /**
   * @dev Validate the proposal.
   *
   * Requirements:
   * - `p.proposer` must be valid candidate address.
   * - `p.expiry` must be greater than or equal to the current block timestamp + `MIN_PROPOSAL_DURATION`.
   * - `p.recipients`, `p.amounts`, and `p.callDatas` must have the same length.
   * - `p.executor` must either be valid address or `address(this)`.
   * - `p.amounts` must not contain zero.
   * - `p.recipients` can contain zero or dead address.
   */
  function validateProposal(
    Proposal calldata p
  ) external view;

  /**
   * @dev Get the global nonce for all current proposal.
   */
  function getGlobalNonce() external view returns (uint32);

  /**
   * @dev Get the threshold for the proposal to pass.
   */
  function getThreshold() external view returns (Threshold memory threshold);

  /**
   * @dev Get the current accumulating vote power.
   */
  function getCurrentVotePower(
    bytes32 hash
  ) external view returns (VotePower memory votePow);

  /**
   * @dev Get the snapshot staked amount of a candidate at the time of proposal creation.
   *
   * Requirements:
   * - `cid` must be valid candidate address.
   * - `hash` must be existed.
   */
  function getSnapshotVotePowerById(bytes32 hash, address cid) external view returns (uint256 votingPower);

  /**
   * @dev Get the total snapshot staked amount of all candidates at the time of proposal creation.
   */
  function getSnapshotTotalVotePower(
    bytes32 hash
  ) external view returns (uint256 totalVotePower);

  /**
   * @dev Get the vote of a candidate.
   */
  function getVote(bytes32 hash, address cid) external view returns (Vote vote);

  /**
   * @dev Get the minimum vote weight required to pass a proposal.
   */
  function getMinimumVotePowerToPass(
    bytes32 hash
  ) external view returns (uint256 minVoteFor);

  /**
   * @dev Get the minimum vote weight required to cancel a proposal.
   */
  function getMinimumVotePowerToCancel(
    bytes32 hash
  ) external view returns (uint256 minVoteAgainst);

  /**
   * @dev Get the proposal data
   *
   * Requirements:
   * - `hash` must be existed.
   */
  function getProposal(
    bytes32 hash
  ) external view returns (Proposal memory proposal);

  /**
   * @dev Get the proposal creation timestamp.
   *
   * Requirements:
   * - `hash` must be existed.
   */
  function getProposalCreatedAt(
    bytes32 hash
  ) external view returns (uint40 createdAt);

  /**
   * @dev Get the pending proposals currently active.
   */
  function getPendingProposals() external view returns (bytes32[] memory hashes);

  /**
   * @dev Get the proposal state { Unknown, Active, Passed, Cancelled, Deprecated }.
   */
  function getState(
    bytes32 hash
  ) external view returns (State state);

  /**
   * @dev Get the hash of a proposal.
   * - Will be hashed with `hashTypedDataV4` to support signature vote in the future.
   */
  function hashProposal(
    Proposal calldata proposal
  ) external view returns (bytes32 hash);
}
