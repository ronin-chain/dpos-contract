// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ballot } from "@ronin/contracts/libraries/Ballot.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import { SignatureConsumer } from "@ronin/contracts/interfaces/consumers/SignatureConsumer.sol";
import { VoteStatusConsumer } from "@ronin/contracts/interfaces/consumers/VoteStatusConsumer.sol";

interface ICoreGovernance is VoteStatusConsumer, SignatureConsumer {
  /**
   * @dev Error thrown when attempting to interact with a finalized vote.
   */
  error ErrVoteIsFinalized();
  /**
   * @dev Error thrown when the current proposal is not completed.
   */
  error ErrCurrentProposalIsNotCompleted();

  /// @dev Emitted when the proposal is approved
  event ProposalApproved(bytes32 indexed proposalHash);
  /// @dev Emitted when a proposal is created
  event ProposalCreated(
    uint256 indexed chainId,
    uint256 indexed round,
    bytes32 indexed proposalHash,
    Proposal.ProposalDetail proposal,
    address creator
  );
  /// @dev Emitted when the proposal is executed
  event ProposalExecuted(bytes32 indexed proposalHash, bool[] successCalls, bytes[] returnDatas);
  /// @dev Emitted when the vote is expired
  event ProposalExpired(bytes32 indexed proposalHash);
  /// @dev Emitted when the proposal expiry duration is changed.
  event ProposalExpiryDurationChanged(uint256 indexed duration);
  /// @dev Emitted when the vote is reject
  event ProposalRejected(bytes32 indexed proposalHash);
  /// @dev Emitted when the proposal is voted
  event ProposalVoted(bytes32 indexed proposalHash, address indexed voter, Ballot.VoteType support, uint256 weight);

  /// @dev Mapping from chain id => vote round
  /// @notice chain id = 0 for global proposal
  function round(
    uint256
  ) external view returns (uint256);

  /// @dev Mapping from chain id => vote round => proposal vote
  function vote(
    uint256,
    uint256
  )
    external
    view
    returns (VoteStatus status, bytes32 hash, uint256 againstVoteWeight, uint256 forVoteWeight, uint256 expiryTimestamp);
}
