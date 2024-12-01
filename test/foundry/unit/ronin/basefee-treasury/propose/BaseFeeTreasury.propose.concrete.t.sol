// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { console } from "forge-std/console.sol";

import { BaseFeeTreasury_Base_Test } from "test/foundry/unit/ronin/basefee-treasury/BaseFeeTreasury.base.t.sol";

import { LibApplyCandidate } from "script/shared/libraries/LibApplyCandidate.sol";
import { LibWrapUpEpoch } from "script/shared/libraries/LibWrapUpEpoch.sol";

import { IBaseFeeTreasury } from "src/interfaces/basefee-treasury/IBaseFeeTreasury.sol";
import { ICandidateManager } from "src/interfaces/validator/ICandidateManager.sol";
import { TConsensus } from "src/udvts/Types.sol";

import { ErrEmptyArray, ErrLengthMismatch, ErrUnauthorized } from "src/utils/CommonErrors.sol";
import { RoleAccess } from "src/utils/RoleAccess.sol";

contract BaseFeeTreasury_Propose_Concrete_Test is BaseFeeTreasury_Base_Test {
  function testConcrete_ActiveProposalDeprecated_WhenPassedExpiry_propose() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);

    vm.warp(block.timestamp + 1 days);

    IBaseFeeTreasury.Proposal memory proposal = this.getValidProposal(cids[0], address(baseFeeTreasury));
    bytes32 hash = baseFeeTreasury.hashProposal(proposal);

    this.propose(admin, proposal, "");

    vm.warp(block.timestamp + proposal.expiry + 1);

    assertTrue(baseFeeTreasury.getState(hash) == IBaseFeeTreasury.State.Deprecated, "Proposal should be deprecated");
    assertNotContain(baseFeeTreasury.getPendingProposals(), hash);
  }

  function testConcrete_SuccessWhen_ChangeAdmin_propose() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);

    vm.warp(block.timestamp + 1 days);

    address newAdm = makeAddr("new-admin");
    vm.prank(admin);
    profile.changeAdminAddr(cids[0], newAdm);

    this.propose(newAdm, this.getValidProposal(cids[0], address(baseFeeTreasury)), "");
  }

  function testConcrete_SuccessWhen_propose() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);

    vm.warp(block.timestamp + 1 days);

    this.propose(admin, this.getValidProposal(cids[0], address(baseFeeTreasury)), "");
  }

  function testConcrete_SuccessWhen_RecipientsAreDuplicated_propose() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);

    vm.warp(block.timestamp + 1 days);

    IBaseFeeTreasury.Proposal memory proposal = this.getValidProposal(cids[0], address(baseFeeTreasury));
    proposal.recipients[0] = payable(address(0x1));
    proposal.recipients[1] = payable(address(0x1));

    this.propose(admin, proposal, "");
  }

  function testConcrete_SuccessWhen_AdminUnstakeToMin_propose() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);
    TConsensus consensus = profile.getId2Consensus(cids[0]);

    (address adm, uint256 selfStake, uint256 totalStake) = staking.getPoolDetailById(cids[0]);
    assertEq(admin, adm, "!admin");

    vm.warp(block.timestamp + 3 days);

    vm.deal(address(baseFeeTreasury), 1 ether);

    uint256 minStake = staking.minValidatorStakingAmount();
    uint256 diff = selfStake - minStake;

    vm.prank(admin);
    staking.unstake(consensus, diff);

    this.propose(admin, this.getValidProposal(cids[0], address(baseFeeTreasury)), "");
  }

  function testConcrete_RevertIf_OnRenunciation_propose() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[cids.length - 1]);
    TConsensus consensus = profile.getId2Consensus(cids[cids.length - 1]);

    vm.warp(block.timestamp + 1 days);

    vm.prank(admin);
    staking.requestRenounce(consensus);

    this.propose(
      admin,
      this.getValidProposal(cids[cids.length - 1], address(baseFeeTreasury)),
      abi.encodeWithSelector(ErrUnauthorized.selector, IBaseFeeTreasury.propose.selector, RoleAccess.CANDIDATE_ADMIN)
    );
  }

  function testConcrete_RevertIf_RenouncedCandidate_propose() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[cids.length - 1]);
    TConsensus consensus = profile.getId2Consensus(cids[cids.length - 1]);

    vm.prank(admin);
    staking.requestRenounce(consensus);

    vm.warp(block.timestamp + staking.waitingSecsToRevoke());
    LibWrapUpEpoch.wrapUpPeriod();

    this.propose(
      admin,
      this.getValidProposal(cids[cids.length - 1], address(baseFeeTreasury)),
      abi.encodeWithSelector(ICandidateManager.ErrNonExistentCandidate.selector)
    );
  }

  function testConcrete_RevertIf_EmergencyExit_propose() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[cids.length - 1]);
    TConsensus consensus = profile.getId2Consensus(cids[cids.length - 1]);

    vm.prank(admin);
    staking.requestEmergencyExit(consensus);

    vm.warp(block.timestamp + staking.waitingSecsToRevoke());
    LibWrapUpEpoch.wrapUpPeriod();

    this.propose(
      admin,
      this.getValidProposal(cids[cids.length - 1], address(baseFeeTreasury)),
      abi.encodeWithSelector(ICandidateManager.ErrNonExistentCandidate.selector)
    );
  }

  function testConcrete_RevertIf_CandidateAdminIsNewlyRegistered_propose() external {
    address cid = makeAddr("new-css");
    address admin = makeAddr("new-candidate-admin");
    LibApplyCandidate.applyValidatorCandidate(address(staking), admin, cid);

    this.propose(
      admin,
      this.getValidProposal(cid, address(baseFeeTreasury)),
      abi.encodeWithSelector(IBaseFeeTreasury.ErrNewlyRegisteredCannotVote.selector, cid)
    );
  }

  function testConcrete_RevertIf_ProposeDuplicate_propose() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);

    vm.warp(block.timestamp + 1 days);

    console.log("ts", block.timestamp, "period", block.timestamp / 1 days);

    IBaseFeeTreasury.Proposal memory proposal = this.getValidProposal(cids[0], address(baseFeeTreasury));
    this.propose(admin, proposal, "");

    this.propose(
      admin,
      proposal,
      abi.encodeWithSelector(
        IBaseFeeTreasury.ErrRequiredStateNotReached.selector,
        baseFeeTreasury.hashProposal(proposal),
        IBaseFeeTreasury.State.Unknown,
        IBaseFeeTreasury.State.Active
      )
    );
  }

  function testConcrete_RevertIf_ProposalNonce_DifferFromGlobalNonce_propose() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);

    IBaseFeeTreasury.Proposal memory proposal = this.getValidProposal(cids[0], address(baseFeeTreasury));
    proposal.nonce = baseFeeTreasury.getGlobalNonce() + 1;

    this.propose(
      admin,
      proposal,
      abi.encodeWithSelector(
        IBaseFeeTreasury.ErrInvalidNonce.selector, baseFeeTreasury.getGlobalNonce(), proposal.nonce
      )
    );

    proposal.nonce = baseFeeTreasury.getGlobalNonce() - 1;

    this.propose(
      admin,
      proposal,
      abi.encodeWithSelector(
        IBaseFeeTreasury.ErrInvalidNonce.selector, baseFeeTreasury.getGlobalNonce(), proposal.nonce
      )
    );
  }

  function testConcrete_RevertIf_ExpiryDurationLesserThan_MIN_PROPOSAL_DURATION_propose() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);

    IBaseFeeTreasury.Proposal memory proposal = this.getValidProposal(cids[0], address(baseFeeTreasury));
    proposal.expiry = uint40(block.timestamp + baseFeeTreasury.MIN_PROPOSAL_DURATION() - 1);

    this.propose(
      admin,
      proposal,
      abi.encodeWithSelector(
        IBaseFeeTreasury.ErrExpiryDurationTooShort.selector,
        block.timestamp + baseFeeTreasury.MIN_PROPOSAL_DURATION(),
        proposal.expiry
      )
    );
  }

  function testConcrete_RevertIf_LengthMismatch_propose() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);

    IBaseFeeTreasury.Proposal memory proposal = this.getValidProposal(cids[0], address(baseFeeTreasury));
    proposal.recipients = new address[](2);
    proposal.amounts = new uint96[](1);
    proposal.callDatas = new bytes[](1);

    this.propose(admin, proposal, abi.encodeWithSelector(ErrLengthMismatch.selector, IBaseFeeTreasury.propose.selector));
  }

  function testConcrete_RevertIf_EmptyProposal_propose() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);

    IBaseFeeTreasury.Proposal memory proposal = this.getValidProposal(cids[0], address(baseFeeTreasury));
    proposal.recipients = new address[](0);
    proposal.amounts = new uint96[](0);
    proposal.callDatas = new bytes[](0);

    this.propose(admin, proposal, abi.encodeWithSelector(ErrEmptyArray.selector));
  }

  function testConcrete_RevertIf_ContainsNullAmount_propose() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);

    IBaseFeeTreasury.Proposal memory proposal = this.getValidProposal(cids[0], address(baseFeeTreasury));
    proposal.amounts[0] = 0;

    this.propose(admin, proposal, abi.encodeWithSelector(IBaseFeeTreasury.ErrZeroAmount.selector, 0));
  }

  function testConcrete_RevertIf_ContainsNullRecipient_propose() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);

    IBaseFeeTreasury.Proposal memory proposal = this.getValidProposal(cids[0], address(baseFeeTreasury));
    proposal.recipients[0] = payable(address(0x0));

    this.propose(
      admin, proposal, abi.encodeWithSelector(IBaseFeeTreasury.ErrInvalidRecipient.selector, 0, address(0x0))
    );
  }

  function testConcrete_RevertIf_ContainsRecipientAsBaseFeeTreasuryAddress_propose() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);

    IBaseFeeTreasury.Proposal memory proposal = this.getValidProposal(cids[0], address(baseFeeTreasury));
    proposal.recipients[0] = payable(address(baseFeeTreasury));

    this.propose(
      admin,
      proposal,
      abi.encodeWithSelector(IBaseFeeTreasury.ErrInvalidRecipient.selector, 0, address(baseFeeTreasury))
    );
  }

  function testConcrete_RevertIf_ExecutorIsNull_propose() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);

    IBaseFeeTreasury.Proposal memory proposal = this.getValidProposal(cids[0], address(baseFeeTreasury));
    proposal.executor = address(0x0);

    this.propose(admin, proposal, abi.encodeWithSelector(IBaseFeeTreasury.ErrInvalidExecutor.selector, address(0x0)));
  }

  function testConcrete_RevertIf_UnauthorizedCaller_propose() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address unauthorized = address(0x1);

    this.propose(
      unauthorized,
      this.getValidProposal(cids[0], address(baseFeeTreasury)),
      abi.encodeWithSelector(ErrUnauthorized.selector, IBaseFeeTreasury.propose.selector, RoleAccess.CANDIDATE_ADMIN)
    );
  }
}
