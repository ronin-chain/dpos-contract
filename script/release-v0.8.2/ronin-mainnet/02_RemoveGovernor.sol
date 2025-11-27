// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";
import { LibProposal, Proposal } from "script/shared/libraries/LibProposal.sol";
import { Contract } from "script/utils/Contract.sol";
import { Network } from "script/utils/Network.sol";
import { IProfile } from "src/interfaces/IProfile.sol";

import { IRoninGovernanceAdmin } from "src/interfaces/IRoninGovernanceAdmin.sol";
import { IRoninTrustedOrganization } from "src/interfaces/IRoninTrustedOrganization.sol";

import { IStaking } from "src/interfaces/staking/IStaking.sol";
import { IRoninValidatorSet } from "src/interfaces/validator/IRoninValidatorSet.sol";
import { TConsensus } from "src/udvts/Types.sol";

import { LibWrapUpEpoch } from "script/shared/libraries/LibWrapUpEpoch.sol";

contract Migration_02_RemoveGovernor is RoninMigration {
  Proposal.ProposalDetail internal _proposal;
  IRoninGovernanceAdmin internal _governanceAdmin;
  IRoninTrustedOrganization internal _trustedOrg;

  uint256 internal constant EXPIRY = 14 days;
  address internal constant proposer = 0xe880802580a1fbdeF67ACe39D1B21c5b2C74f059;
  TConsensus internal constant randomConsensus = TConsensus.wrap(0x6E46924371d0e910769aaBE0d867590deAC20684);
  IRoninTrustedOrganization.TrustedOrganization internal _randomGVProfileBefore;
  IRoninTrustedOrganization.TrustedOrganization internal _randomGVProfileAfter;
  address internal constant newGovernor = 0x626A7a015410ecE480e5c3DE206a5Bdc3d78A2a9;

  function _preCheck() internal virtual override {
    _trustedOrg = IRoninTrustedOrganization(loadContract(Contract.RoninTrustedOrganization.key()));

    _randomGVProfileBefore = _trustedOrg.getTrustedOrganization(randomConsensus);
    console.log("randomGVProfileBefore.governor", _randomGVProfileBefore.governor);
    console.log("randomGVProfileBefore.weight", _randomGVProfileBefore.weight);
    console.log("randomGVProfileBefore.addedBlock", _randomGVProfileBefore.addedBlock);
    console.log("randomGVProfileBefore.consensusAddr", TConsensus.unwrap(_randomGVProfileBefore.consensusAddr));
    console.log("randomGVProfileBefore.__deprecatedBridgeVoter", _randomGVProfileBefore.__deprecatedBridgeVoter);
  }

  function run() public {
    address[] memory targets = new address[](1);
    targets[0] = loadContract(Contract.RoninTrustedOrganization.key());

    TConsensus[] memory removeList = new TConsensus[](1);
    removeList[0] = randomConsensus;

    bytes[] memory callDatas = new bytes[](1);
    callDatas[0] = abi.encodeWithSignature(
      "functionDelegateCall(bytes)", abi.encodeCall(IRoninTrustedOrganization.removeTrustedOrganizations, (removeList))
    );

    uint256[] memory values = new uint256[](1);

    _governanceAdmin = IRoninGovernanceAdmin(loadContract(Contract.RoninGovernanceAdmin.key()));
    _proposal = LibProposal.buildProposal(_governanceAdmin, vm.getBlockTimestamp() + EXPIRY, targets, values, callDatas);
    LibProposal.proposeProposal(_governanceAdmin, _trustedOrg, _proposal, proposer);
  }

  function _postCheck() internal virtual override {
    LibProposal.voteProposalUntilExecute(_governanceAdmin, _trustedOrg, _proposal);
    address randomGVAdmin =
      IProfile(loadContract(Contract.Profile.key())).getId2Admin(TConsensus.unwrap(randomConsensus));
    IStaking staking = IStaking(loadContract(Contract.Staking.key()));
    vm.prank(randomGVAdmin);
    staking.requestRenounce(randomConsensus);

    _randomGVProfileAfter = _trustedOrg.getTrustedOrganization(randomConsensus);
    // Assert removed
    assertEq(_trustedOrg.getTrustedOrganization(randomConsensus).governor, address(0), "governor should be removed");
    assertEq(_trustedOrg.getTrustedOrganization(randomConsensus).weight, 0, "weight should be 0");
    assertEq(_trustedOrg.getTrustedOrganization(randomConsensus).addedBlock, 0, "addedBlock should be 0");

    assertEq(
      _trustedOrg.getTrustedOrganization(randomConsensus).__deprecatedBridgeVoter,
      address(0),
      "deprecatedBridgeVoter should be 0"
    );

    IRoninValidatorSet validatorSet = IRoninValidatorSet(loadContract(Contract.RoninValidatorSet.key()));

    uint256 revokingTimestamp = validatorSet.getCandidateInfo(randomConsensus).revokingTimestamp;
    assertTrue(revokingTimestamp > 0, "revokingTimestamp should be greater than 0");
    uint256 balanceBefore = randomGVAdmin.balance;

    LibWrapUpEpoch.fastForwardToNextDay();
    LibWrapUpEpoch.wrapUpEpoch();

    uint256 balanceAfter = randomGVAdmin.balance;
    assertTrue(balanceAfter > balanceBefore, "balance should be greater than 0");

    assertTrue(validatorSet.isValidatorCandidate(randomConsensus), "random gv should still be a validator candidate");
    assertTrue(validatorSet.isBlockProducer(randomConsensus), "random gv should still be a block producer");

    LibWrapUpEpoch.wrapUpEpoch();

    // Assert random gv is removed from validator set
    assertFalse(validatorSet.isValidatorCandidate(randomConsensus), "random gv should be removed from validator set");
    assertFalse(validatorSet.isBlockProducer(randomConsensus), "random gv should be removed from block producer");

    super._postCheck();
  }

  function _afterRunningScript() internal virtual override { }
}
