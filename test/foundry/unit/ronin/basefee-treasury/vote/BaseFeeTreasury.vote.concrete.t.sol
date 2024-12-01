// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { IBaseFeeTreasury } from "src/interfaces/basefee-treasury/IBaseFeeTreasury.sol";

import { LibApplyCandidate } from "script/shared/libraries/LibApplyCandidate.sol";
import { BaseFeeTreasury_Base_Test } from "test/foundry/unit/ronin/basefee-treasury/BaseFeeTreasury.base.t.sol";

contract BaseFeeTreasury_Vote_Concrete_Test is BaseFeeTreasury_Base_Test {
  function testConcrete_RevertIf_ActiveProposal_IsCancelledByProposer_CannotVoteFor_vote() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address proposerAdmin = profile.getId2Admin(cids[0]);
    address admin = profile.getId2Admin(cids[1]);

    vm.warp(block.timestamp + 1 days);

    IBaseFeeTreasury.Proposal memory proposal = this.getValidProposal(cids[0], address(baseFeeTreasury));
    bytes32 hash = baseFeeTreasury.hashProposal(proposal);

    this.propose(proposerAdmin, proposal, "");

    this.cancel(proposerAdmin, hash, "");

    this.vote(
      admin,
      cids[1],
      hash,
      IBaseFeeTreasury.Vote.For,
      abi.encodeWithSelector(
        IBaseFeeTreasury.ErrRequiredStateNotReached.selector,
        hash,
        IBaseFeeTreasury.State.Active,
        IBaseFeeTreasury.State.Cancelled
      )
    );

    assertNotContain(baseFeeTreasury.getPendingProposals(), hash);
  }

  function testConcrete_AutoExecuteProposal_WhenExecutorIsContractItself_VoteTilMetMinimumVoteForPower_vote() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);

    vm.warp(block.timestamp + 1 days);
    vm.deal(address(baseFeeTreasury), 100 ether);

    IBaseFeeTreasury.Proposal memory proposal = this.getValidProposal(cids[0], address(baseFeeTreasury));
    bytes32 hash = baseFeeTreasury.hashProposal(proposal);

    this.propose(admin, proposal, "");

    uint256 idx = 1;

    while (baseFeeTreasury.getCurrentVotePower(hash).vFor < baseFeeTreasury.getMinimumVotePowerToPass(hash)) {
      this.vote(profile.getId2Admin(cids[idx]), cids[idx], hash, IBaseFeeTreasury.Vote.For, "");
      idx = (idx + 1) % cids.length;
    }

    assertNotContain(baseFeeTreasury.getPendingProposals(), hash);
    assertTrue(baseFeeTreasury.getState(hash) == IBaseFeeTreasury.State.Executed, "Proposal should be executed");
  }

  function testConcrete_ProposalIsCancelled_VoteTilMetMinimumVoteAgainstPower_vote() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);

    vm.warp(block.timestamp + 1 days);

    IBaseFeeTreasury.Proposal memory proposal = this.getValidProposal(cids[0], address(baseFeeTreasury));
    bytes32 hash = baseFeeTreasury.hashProposal(proposal);

    this.propose(admin, proposal, "");

    uint256 idx = 1;

    while (baseFeeTreasury.getCurrentVotePower(hash).vAgainst < baseFeeTreasury.getMinimumVotePowerToCancel(hash)) {
      this.vote(profile.getId2Admin(cids[idx]), cids[idx], hash, IBaseFeeTreasury.Vote.Against, "");
      idx = (idx + 1) % cids.length;
    }

    assertNotContain(baseFeeTreasury.getPendingProposals(), hash);
    assertTrue(baseFeeTreasury.getState(hash) == IBaseFeeTreasury.State.Cancelled, "Proposal should be cancelled");
  }

  function testConcrete_PassedProposalDeprecated_WhenPassedExpiry_vote() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);

    vm.warp(block.timestamp + 1 days);
    vm.deal(address(baseFeeTreasury), 100 ether);

    address customExecutor = makeAddr("custom-executor");

    IBaseFeeTreasury.Proposal memory proposal = this.getValidProposal(cids[0], customExecutor);
    bytes32 hash = baseFeeTreasury.hashProposal(proposal);

    this.propose(admin, proposal, "");

    uint256 idx = 1;

    while (baseFeeTreasury.getCurrentVotePower(hash).vFor < baseFeeTreasury.getMinimumVotePowerToPass(hash)) {
      this.vote(profile.getId2Admin(cids[idx]), cids[idx], hash, IBaseFeeTreasury.Vote.For, "");
      idx = (idx + 1) % cids.length;
    }

    assertTrue(baseFeeTreasury.getState(hash) == IBaseFeeTreasury.State.Passed, "Proposal should be passed");

    vm.warp(proposal.expiry + 1);

    assertTrue(baseFeeTreasury.getState(hash) == IBaseFeeTreasury.State.Deprecated, "Proposal should be deprecated");
    assertNotContain(baseFeeTreasury.getPendingProposals(), hash);
  }

  function testConcrete_SuccessWhen_VoteTilMetMinimumVoteForPower_NotExecuted_vote() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);

    vm.warp(block.timestamp + 1 days);
    vm.deal(address(baseFeeTreasury), 100 ether);

    address customExecutor = makeAddr("custom-executor");

    IBaseFeeTreasury.Proposal memory proposal = this.getValidProposal(cids[0], customExecutor);
    bytes32 hash = baseFeeTreasury.hashProposal(proposal);

    this.propose(admin, proposal, "");

    uint256 idx = 1;

    while (baseFeeTreasury.getCurrentVotePower(hash).vFor < baseFeeTreasury.getMinimumVotePowerToPass(hash)) {
      this.vote(profile.getId2Admin(cids[idx]), cids[idx], hash, IBaseFeeTreasury.Vote.For, "");
      idx = (idx + 1) % cids.length;
    }

    assertTrue(baseFeeTreasury.getState(hash) == IBaseFeeTreasury.State.Passed, "Proposal should be passed");
    assertNotContain(baseFeeTreasury.getPendingProposals(), hash);

    this.execute(customExecutor, hash, "");
  }

  function testConcrete_RevertIf_ContinueToVoteIfProposalAlreadyCancelled_vote() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);

    vm.warp(block.timestamp + 1 days);

    IBaseFeeTreasury.Proposal memory proposal = this.getValidProposal(cids[0], address(baseFeeTreasury));
    bytes32 hash = baseFeeTreasury.hashProposal(proposal);

    this.propose(admin, proposal, "");

    uint256 idx = 1;

    while (baseFeeTreasury.getCurrentVotePower(hash).vAgainst < baseFeeTreasury.getMinimumVotePowerToCancel(hash)) {
      this.vote(profile.getId2Admin(cids[idx]), cids[idx], hash, IBaseFeeTreasury.Vote.Against, "");
      idx = (idx + 1) % cids.length;
    }

    this.vote(
      profile.getId2Admin(cids[0]),
      cids[0],
      hash,
      IBaseFeeTreasury.Vote.For,
      abi.encodeWithSelector(
        IBaseFeeTreasury.ErrRequiredStateNotReached.selector,
        hash,
        IBaseFeeTreasury.State.Active,
        IBaseFeeTreasury.State.Cancelled
      )
    );
  }

  function testConcrete_RevertIf_ContinueToVoteIfProposalAlreadyPassed_vote() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);

    vm.warp(block.timestamp + 1 days);
    vm.deal(address(baseFeeTreasury), 100 ether);

    address customExecutor = makeAddr("custom-executor");

    IBaseFeeTreasury.Proposal memory proposal = this.getValidProposal(cids[0], customExecutor);
    bytes32 hash = baseFeeTreasury.hashProposal(proposal);

    this.propose(admin, proposal, "");

    uint256 idx = 1;

    while (baseFeeTreasury.getCurrentVotePower(hash).vFor < baseFeeTreasury.getMinimumVotePowerToPass(hash)) {
      this.vote(profile.getId2Admin(cids[idx]), cids[idx], hash, IBaseFeeTreasury.Vote.For, "");
      idx = (idx + 1) % cids.length;
    }

    this.vote(
      profile.getId2Admin(cids[0]),
      cids[0],
      hash,
      IBaseFeeTreasury.Vote.For,
      abi.encodeWithSelector(
        IBaseFeeTreasury.ErrRequiredStateNotReached.selector,
        hash,
        IBaseFeeTreasury.State.Active,
        IBaseFeeTreasury.State.Passed
      )
    );
  }

  function testConcrete_SuccessWhen_VoteFor_vote() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);

    vm.warp(block.timestamp + 1 days);

    IBaseFeeTreasury.Proposal memory proposal = this.getValidProposal(cids[0], address(baseFeeTreasury));
    bytes32 hash = baseFeeTreasury.hashProposal(proposal);

    this.propose(admin, proposal, "");

    this.vote(profile.getId2Admin(cids[1]), cids[1], hash, IBaseFeeTreasury.Vote.For, "");
  }

  function testConcrete_RevertIf_NewlyRegisterBeforeProposalCreated_vote() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);

    address newAdmin = makeAddr("new-candidate-admin");
    address newCssAddr = makeAddr("new-css-addr");

    vm.warp(block.timestamp + 1 days);

    LibApplyCandidate.applyValidatorCandidate(address(staking), newAdmin, newCssAddr);

    IBaseFeeTreasury.Proposal memory proposal = this.getValidProposal(cids[0], address(baseFeeTreasury));
    bytes32 hash = baseFeeTreasury.hashProposal(proposal);

    this.propose(admin, proposal, "");

    this.vote(
      newAdmin,
      newCssAddr,
      hash,
      IBaseFeeTreasury.Vote.For,
      abi.encodeWithSelector(IBaseFeeTreasury.ErrNewlyRegisteredCannotVote.selector, newCssAddr)
    );
  }

  function testConcrete_RevertIf_NewlyRegisterAfterProposalCreated_vote() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);

    vm.warp(block.timestamp + 1 days);

    IBaseFeeTreasury.Proposal memory proposal = this.getValidProposal(cids[0], address(baseFeeTreasury));
    bytes32 hash = baseFeeTreasury.hashProposal(proposal);

    this.propose(admin, proposal, "");

    address newAdmin = makeAddr("new-candidate-admin");
    address newCssAddr = makeAddr("new-css-addr");

    LibApplyCandidate.applyValidatorCandidate(address(staking), newAdmin, newCssAddr);

    this.vote(
      newAdmin,
      newCssAddr,
      hash,
      IBaseFeeTreasury.Vote.For,
      abi.encodeWithSelector(IBaseFeeTreasury.ErrNewlyRegisteredOrRenouncedOrEmergencyExit.selector)
    );
  }

  function testConcrete_RevertIf_VoteUnknown_vote() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);

    vm.warp(block.timestamp + 1 days);

    IBaseFeeTreasury.Proposal memory proposal = this.getValidProposal(cids[0], address(baseFeeTreasury));
    bytes32 hash = baseFeeTreasury.hashProposal(proposal);

    this.propose(admin, proposal, "");

    this.vote(
      profile.getId2Admin(cids[1]),
      cids[1],
      hash,
      IBaseFeeTreasury.Vote.Unknown,
      abi.encodeWithSelector(IBaseFeeTreasury.ErrInvalidVote.selector)
    );
  }

  function testConcrete_RevertIf_AlreadyVoted_VoteAgainWithDifferentVote_vote() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);

    vm.warp(block.timestamp + 1 days);

    IBaseFeeTreasury.Proposal memory proposal = this.getValidProposal(cids[0], address(baseFeeTreasury));
    bytes32 hash = baseFeeTreasury.hashProposal(proposal);

    this.propose(admin, proposal, "");

    this.vote(profile.getId2Admin(cids[1]), cids[1], hash, IBaseFeeTreasury.Vote.For, "");

    this.vote(
      profile.getId2Admin(cids[1]),
      cids[1],
      hash,
      IBaseFeeTreasury.Vote.Against,
      abi.encodeWithSelector(IBaseFeeTreasury.ErrAlreadyVoted.selector, hash, cids[1], IBaseFeeTreasury.Vote.For)
    );
  }

  function testConcrete_RevertIf_AlreadyVoted_VoteAgainWithSameVote_vote() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);

    vm.warp(block.timestamp + 1 days);

    IBaseFeeTreasury.Proposal memory proposal = this.getValidProposal(cids[0], address(baseFeeTreasury));
    bytes32 hash = baseFeeTreasury.hashProposal(proposal);

    this.propose(admin, proposal, "");

    this.vote(profile.getId2Admin(cids[1]), cids[1], hash, IBaseFeeTreasury.Vote.For, "");

    this.vote(
      profile.getId2Admin(cids[1]),
      cids[1],
      hash,
      IBaseFeeTreasury.Vote.For,
      abi.encodeWithSelector(IBaseFeeTreasury.ErrAlreadyVoted.selector, hash, cids[1], IBaseFeeTreasury.Vote.For)
    );
  }

  function testConcrete_SuccessWhen_VoteAgainst_vote() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);

    vm.warp(block.timestamp + 1 days);

    IBaseFeeTreasury.Proposal memory proposal = this.getValidProposal(cids[0], address(baseFeeTreasury));
    bytes32 hash = baseFeeTreasury.hashProposal(proposal);

    this.propose(admin, proposal, "");

    this.vote(profile.getId2Admin(cids[1]), cids[1], hash, IBaseFeeTreasury.Vote.Against, "");
  }

  function testConcrete_RevertIf_InexistentProposal_vote() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address proposer = profile.getId2Admin(cids[0]);
    address admin = profile.getId2Admin(cids[1]);

    IBaseFeeTreasury.Proposal memory proposal = this.getValidProposal(proposer, address(baseFeeTreasury));
    bytes32 hash = baseFeeTreasury.hashProposal(proposal);

    this.vote(
      admin,
      cids[1],
      hash,
      IBaseFeeTreasury.Vote.For,
      abi.encodeWithSelector(
        IBaseFeeTreasury.ErrRequiredStateNotReached.selector,
        hash,
        IBaseFeeTreasury.State.Active,
        IBaseFeeTreasury.State.Unknown
      )
    );
  }
}
