// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ballot } from "../../../libraries/Ballot.sol";
import { ICoreGovernance } from "./ICoreGovernance.sol";

interface IGovernanceProposal is ICoreGovernance {
  /**
   * @dev See {CommonGovernanceProposal-_getProposalSignatures}
   */
  function getProposalSignatures(
    uint256 chainId,
    uint256 round
  ) external view returns (address[] memory voters, Ballot.VoteType[] memory supports_, Signature[] memory signatures);

  /**
   * @dev See {CommonGovernanceProposal-_proposalVoted}
   */
  function proposalVoted(uint256 chainId, uint256 round, address voter) external view returns (bool);
}
