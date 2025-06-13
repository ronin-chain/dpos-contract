// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ballot } from "../libraries/Ballot.sol";
import { Proposal } from "../libraries/Proposal.sol";
import { IGovernanceAdmin } from "./extensions/IGovernanceAdmin.sol";

interface IRoninGovernanceAdmin is IGovernanceAdmin {
  /// @dev Emitted when an emergency exit poll is created.
  event EmergencyExitPollCreated(
    bytes32 voteHash, address validatorId, address recipientAfterUnlockedFund, uint256 requestedAt, uint256 expiredAt
  );
  /// @dev Emitted when an emergency exit poll is approved.
  event EmergencyExitPollApproved(bytes32 voteHash);
  /// @dev Emitted when an emergency exit poll is expired.
  event EmergencyExitPollExpired(bytes32 voteHash);
  /// @dev Emitted when an emergency exit poll is voted.
  event EmergencyExitPollVoted(bytes32 indexed voteHash, address indexed voter);

  /**
   * @dev Create a vote to agree that an emergency exit is valid and should return the locked funds back.a
   *
   * Requirements:
   * - The method caller is validator contract.
   *
   */
  function createEmergencyExitPoll(
    address validatorId,
    address recipientAfterUnlockedFund,
    uint256 requestedAt,
    uint256 expiredAt
  ) external;

  /**
   * @dev Casts vote for a proposal on the current network.
   *
   * Requirements:
   * - The method caller is governor.
   *
   */
  function castProposalBySignatures(
    Proposal.ProposalDetail memory _proposal,
    Ballot.VoteType[] memory _supports,
    Signature[] memory _signatures
  ) external;

  function castProposalVoteForCurrentNetwork(
    Proposal.ProposalDetail memory _proposal,
    Ballot.VoteType _support
  ) external;

  function deleteExpired(uint256 chainId, uint256 _round) external;

  function emergencyPollVoted(bytes32 _voteHash, address _voter) external view returns (bool);

  function propose(
    uint256 chainId,
    uint256 expiryTimestamp,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    uint256[] memory gasAmounts
  ) external;

  function proposeProposalForCurrentNetwork(
    uint256 expiryTimestamp,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    uint256[] memory gasAmounts,
    Ballot.VoteType _support
  ) external;

  function proposeProposalStructAndCastVotes(
    Proposal.ProposalDetail memory _proposal,
    Ballot.VoteType[] memory _supports,
    Signature[] memory _signatures
  ) external;

  function voteEmergencyExit(
    bytes32 voteHash,
    address validatorId,
    address recipientAfterUnlockedFund,
    uint256 requestedAt,
    uint256 expiredAt
  ) external;
}
