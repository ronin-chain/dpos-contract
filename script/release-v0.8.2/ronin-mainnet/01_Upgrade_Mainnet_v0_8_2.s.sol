// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";
import { LibProposal, Proposal } from "script/shared/libraries/LibProposal.sol";
import { Contract } from "script/utils/Contract.sol";
import { Network } from "script/utils/Network.sol";
import { IRoninGovernanceAdmin } from "src/interfaces/IRoninGovernanceAdmin.sol";
import { IRoninTrustedOrganization } from "src/interfaces/IRoninTrustedOrganization.sol";
import { TConsensus } from "src/udvts/Types.sol";

contract Migration_01_Upgrade_Mainnet_Release_v0_8_2 is RoninMigration {
  Proposal.ProposalDetail internal _proposal;
  IRoninGovernanceAdmin internal _governanceAdmin;
  IRoninTrustedOrganization internal _trustedOrg;

  uint256 internal constant EXPIRY = 14 days;
  address internal constant proposer = 0xe880802580a1fbdeF67ACe39D1B21c5b2C74f059;
  TConsensus internal constant stableNodeConsensus = TConsensus.wrap(0x6E46924371d0e910769aaBE0d867590deAC20684);
  IRoninTrustedOrganization.TrustedOrganization internal _stableNodeBefore;
  IRoninTrustedOrganization.TrustedOrganization internal _stableNodeAfter;
  address internal constant newGovernor = 0x626A7a015410ecE480e5c3DE206a5Bdc3d78A2a9;

  function _preCheck() internal virtual override {
    _trustedOrg = IRoninTrustedOrganization(loadContract(Contract.RoninTrustedOrganization.key()));

    _stableNodeBefore = _trustedOrg.getTrustedOrganization(stableNodeConsensus);
    console.log("stableNodeBefore.governor", _stableNodeBefore.governor);
    console.log("stableNodeBefore.weight", _stableNodeBefore.weight);
    console.log("stableNodeBefore.addedBlock", _stableNodeBefore.addedBlock);
    console.log("stableNodeBefore.consensusAddr", TConsensus.unwrap(_stableNodeBefore.consensusAddr));
    console.log("stableNodeBefore.__deprecatedBridgeVoter", _stableNodeBefore.__deprecatedBridgeVoter);
  }

  function run() public {
    address newStaking = _deployLogic(Contract.Staking.key());
    address newMaintenance = _deployLogic(Contract.Maintenance.key());

    address[] memory targets = new address[](3);
    targets[0] = loadContract(Contract.Staking.key());
    targets[1] = loadContract(Contract.Maintenance.key());
    targets[2] = loadContract(Contract.RoninTrustedOrganization.key());

    IRoninTrustedOrganization.TrustedOrganization memory stableNode = IRoninTrustedOrganization.TrustedOrganization({
      consensusAddr: stableNodeConsensus,
      __deprecatedBridgeVoter: address(0),
      weight: 100,
      governor: newGovernor,
      addedBlock: 0
    });

    IRoninTrustedOrganization.TrustedOrganization[] memory updateList =
      new IRoninTrustedOrganization.TrustedOrganization[](1);
    updateList[0] = stableNode;

    bytes[] memory callDatas = new bytes[](3);
    callDatas[0] = abi.encodeWithSignature("upgradeTo(address)", newStaking);
    callDatas[1] = abi.encodeWithSignature("upgradeTo(address)", newMaintenance);
    callDatas[2] = abi.encodeWithSignature(
      "functionDelegateCall(bytes)", abi.encodeCall(IRoninTrustedOrganization.updateTrustedOrganizations, (updateList))
    );

    uint256[] memory values = new uint256[](3);

    _governanceAdmin = IRoninGovernanceAdmin(loadContract(Contract.RoninGovernanceAdmin.key()));

    _proposal = LibProposal.buildProposal(_governanceAdmin, vm.getBlockTimestamp() + EXPIRY, targets, values, callDatas);
    LibProposal.proposeProposal(_governanceAdmin, _trustedOrg, _proposal, proposer);
  }

  function _postCheck() internal virtual override {
    LibProposal.voteProposalUntilExecute(_governanceAdmin, _trustedOrg, _proposal);

    _stableNodeAfter = _trustedOrg.getTrustedOrganization(stableNodeConsensus);
    console.log("stableNodeAfter.governor", _stableNodeAfter.governor);
    console.log("stableNodeAfter.weight", _stableNodeAfter.weight);
    console.log("stableNodeAfter.addedBlock", _stableNodeAfter.addedBlock);
    console.log("stableNodeAfter.consensusAddr", TConsensus.unwrap(_stableNodeAfter.consensusAddr));
    console.log("stableNodeAfter.__deprecatedBridgeVoter", _stableNodeAfter.__deprecatedBridgeVoter);

    // Assert nothing changed except for the governor
    assertEq(_stableNodeAfter.governor, newGovernor, "governor should be updated");
    assertEq(_stableNodeAfter.weight, _stableNodeBefore.weight, "weight should be unchanged");
    assertEq(_stableNodeAfter.addedBlock, _stableNodeBefore.addedBlock, "addedBlock should be unchanged");
    assertEq(
      TConsensus.unwrap(_stableNodeAfter.consensusAddr),
      TConsensus.unwrap(_stableNodeBefore.consensusAddr),
      "consensusAddr should be unchanged"
    );
    assertEq(
      _stableNodeAfter.__deprecatedBridgeVoter,
      _stableNodeBefore.__deprecatedBridgeVoter,
      "deprecatedBridgeVoter should be unchanged"
    );

    // super._postCheck();
  }

  function _afterRunningScript() internal virtual override { }
}
