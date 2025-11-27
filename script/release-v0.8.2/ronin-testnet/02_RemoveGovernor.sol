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

contract Migration_02_RemoveGovernor_Testnet is RoninMigration {
  Proposal.ProposalDetail internal _proposal;
  IRoninGovernanceAdmin internal _governanceAdmin;
  IRoninTrustedOrganization internal _trustedOrg;

  TConsensus internal constant randomConsensus = TConsensus.wrap(0x9f1Abc67beA4db5560371fF3089F4Bfe934c36Bc);
  IRoninTrustedOrganization.TrustedOrganization internal _randomGVProfileBefore;
  IRoninTrustedOrganization.TrustedOrganization internal _randomGVProfileAfter;

  address internal randomGVAdmin;

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
    _proposal =
      LibProposal.buildProposal(_governanceAdmin, vm.getBlockTimestamp() + 1 hours, targets, values, callDatas);
    LibProposal.executeProposal(_governanceAdmin, _trustedOrg, _proposal);

    randomGVAdmin = IProfile(loadContract(Contract.Profile.key())).getId2Admin(TConsensus.unwrap(randomConsensus));
    IStaking staking = IStaking(loadContract(Contract.Staking.key()));
    vm.broadcast(randomGVAdmin);
    staking.requestRenounce(randomConsensus);
  }

  function _postCheck() internal virtual override {
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

    assertTrue(validatorSet.isValidatorCandidate(randomConsensus), "random gv should still be a validator candidate");
    assertTrue(validatorSet.isBlockProducer(randomConsensus), "random gv should still be a block producer");

    uint256 revokingTimestamp = validatorSet.getCandidateInfo(randomConsensus).revokingTimestamp;
    assertTrue(revokingTimestamp > 0, "revokingTimestamp should be greater than 0");
    uint256 balanceBefore = randomGVAdmin.balance;

    vm.warp(revokingTimestamp + 1);
    LibWrapUpEpoch.wrapUpEpoch();
    assertGt(vm.getBlockTimestamp(), revokingTimestamp, "block timestamp should be greater than revokingTimestamp");

    uint256 balanceAfter = randomGVAdmin.balance;
    assertTrue(balanceAfter > balanceBefore, "balance should be greater than 0");
    console.log("random gv refunded staking amount", balanceAfter - balanceBefore);

    // Assert random gv is removed from validator set
    assertFalse(validatorSet.isValidatorCandidate(randomConsensus), "random gv should be removed from validator set");
    assertFalse(validatorSet.isBlockProducer(randomConsensus), "random gv should be removed from block producer");

    // super._postCheck();
  }

  function _afterRunningScript() internal virtual override { }
}
