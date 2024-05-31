// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { IGeneralConfig } from "@fdk/interfaces/IGeneralConfig.sol";
import { LibSharedAddress } from "@fdk/libraries/LibSharedAddress.sol";
import { RoninGovernanceAdmin } from "@ronin/contracts/ronin/RoninGovernanceAdmin.sol";
import { RoninTrustedOrganization } from "@ronin/contracts/multi-chains/RoninTrustedOrganization.sol";
import { IRoninTrustedOrganization } from "@ronin/contracts/interfaces/IRoninTrustedOrganization.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import { Ballot } from "@ronin/contracts/libraries/Ballot.sol";
import { LibErrorHandler } from "contract-libs/LibErrorHandler.sol";
import { VoteStatusConsumer } from "@ronin/contracts/interfaces/consumers/VoteStatusConsumer.sol";

library LibProposal {
  using StdStyle for *;
  using LibErrorHandler for bool;

  uint256 internal constant DEFAULT_PROPOSAL_GAS = 1_000_000;
  Vm internal constant vm = Vm(LibSharedAddress.VM);
  IGeneralConfig internal constant config = IGeneralConfig(LibSharedAddress.VME);

  function executeProposal(
    RoninGovernanceAdmin governanceAdmin,
    RoninTrustedOrganization roninTrustedOrg,
    Proposal.ProposalDetail memory proposal
  ) internal {
    proposeProposal(governanceAdmin, roninTrustedOrg, proposal, address(0));
    voteProposalUntilSuccess(governanceAdmin, roninTrustedOrg, proposal);
  }

  function voteProposalUntilSuccess(
    RoninGovernanceAdmin governanceAdmin,
    RoninTrustedOrganization roninTrustedOrg,
    Proposal.ProposalDetail memory proposal
  ) internal {
    Ballot.VoteType support = Ballot.VoteType.For;
    IRoninTrustedOrganization.TrustedOrganization[] memory allTrustedOrgs = roninTrustedOrg.getAllTrustedOrganizations();

    bool shouldPrankOnly = config.isPostChecking();

    uint256 totalGas;
    for (uint256 i; i < proposal.gasAmounts.length; ++i) {
      totalGas += proposal.gasAmounts[i];
    }
    totalGas += (totalGas * 20_00) / 100_00;

    if (totalGas < DEFAULT_PROPOSAL_GAS) {
      totalGas = (DEFAULT_PROPOSAL_GAS * 120_00) / 100_00;
    }

    for (uint256 i = 0; i < allTrustedOrgs.length; ++i) {
      address iTrustedOrg = allTrustedOrgs[i].governor;

      (VoteStatusConsumer.VoteStatus status,,,,) = governanceAdmin.vote(block.chainid, proposal.nonce);
      if (governanceAdmin.proposalVoted(block.chainid, proposal.nonce, iTrustedOrg)) {
        continue;
      }

      if (status != VoteStatusConsumer.VoteStatus.Pending) {
        break;
      }

      if (shouldPrankOnly) {
        vm.prank(iTrustedOrg);
      } else {
        vm.broadcast(iTrustedOrg);
      }
      governanceAdmin.castProposalVoteForCurrentNetwork{ gas: totalGas }(proposal, support);
    }
  }

  function proposeProposal(
    RoninGovernanceAdmin governanceAdmin,
    RoninTrustedOrganization roninTrustedOrg,
    Proposal.ProposalDetail memory proposal,
    address proposer
  ) internal {
    if (proposer == address(0)) {
      IRoninTrustedOrganization.TrustedOrganization[] memory allTrustedOrgs =
        roninTrustedOrg.getAllTrustedOrganizations();

      proposer = allTrustedOrgs[0].governor;
    }

    bool shouldPrankOnly = config.isPostChecking();
    if (shouldPrankOnly) {
      vm.prank(proposer);
    } else {
      vm.broadcast(proposer);
    }
    governanceAdmin.proposeProposalForCurrentNetwork(
      proposal.expiryTimestamp,
      proposal.targets,
      proposal.values,
      proposal.calldatas,
      proposal.gasAmounts,
      Ballot.VoteType.For
    );
  }

  function executeProposal(
    RoninGovernanceAdmin governanceAdmin,
    RoninTrustedOrganization roninTrustedOrg,
    Proposal.ProposalDetail memory proposal,
    address proposer
  ) internal {
    proposeProposal(governanceAdmin, roninTrustedOrg, proposal, proposer);
    voteProposalUntilSuccess(governanceAdmin, roninTrustedOrg, proposal);
  }

  function buildProposal(
    RoninGovernanceAdmin governanceAdmin,
    uint256 expiry,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory callDatas
  ) internal returns (Proposal.ProposalDetail memory proposal) {
    require(targets.length == values.length && values.length == callDatas.length, "LibProposal: Length mismatch");

    uint256[] memory gasAmounts = new uint256[](targets.length);

    uint256 snapshotId = vm.snapshot();
    vm.startPrank(address(governanceAdmin));

    {
      for (uint256 i; i < targets.length; ++i) {
        vm.deal(address(governanceAdmin), values[i]);
        uint256 gas = gasleft();
        (bool success, bytes memory returnOrRevertData) = targets[i].call{ value: values[i] }(callDatas[i]);
        gas -= gasleft();
        success.handleRevert(msg.sig, returnOrRevertData);
        // add 50% extra gas amount
        gasAmounts[i] = gas < DEFAULT_PROPOSAL_GAS / 2 ? DEFAULT_PROPOSAL_GAS : (gas * 200_00) / 100_00;
      }
    }
    vm.stopPrank();
    vm.revertTo(snapshotId);

    proposal = Proposal.ProposalDetail(
      governanceAdmin.round(block.chainid) + 1, block.chainid, expiry, targets, values, callDatas, gasAmounts
    );

    logProposal(address(governanceAdmin), proposal);
  }

  function logProposal(address governanceAdmin, Proposal.ProposalDetail memory proposal) internal {
    if (config.isPostChecking()) {
      console.log(StdStyle.italic(StdStyle.magenta("Proposal details omitted:")));
      printLogProposalSummary(governanceAdmin, proposal);
    } else {
      printLogProposal(address(governanceAdmin), proposal);
    }
  }

  function printLogProposalSummary(address governanceAdmin, Proposal.ProposalDetail memory proposal) internal view {
    console.log(
      string.concat(
        "\tGovernance Admin:          \t",
        vm.getLabel(governanceAdmin),
        "\n\tNonce:                   \t",
        vm.toString(proposal.nonce),
        "\n\tExpiry:                  \t",
        vm.toString(proposal.expiryTimestamp),
        "\n\tNumber of internal calls:\t",
        vm.toString(proposal.targets.length),
        "\n"
      )
    );
  }

  function printLogProposal(address governanceAdmin, Proposal.ProposalDetail memory proposal) internal {
    console.log(
      // string.concat(
      StdStyle.magenta("\n================================= Proposal Detail =================================\n")
    );
    //   "GovernanceAdmin: ",
    //   vm.getLabel(governanceAdmin),
    //   "\tNonce: ",
    //   vm.toString(proposal.nonce),
    //   "\tExpiry: ",
    //   vm.toString(proposal.expiryTimestamp)
    // )

    printLogProposalSummary(governanceAdmin, proposal);

    string[] memory commandInput = new string[](3);
    commandInput[0] = "cast";
    commandInput[1] = "4byte-decode";

    bytes[] memory decodedCallDatas = new bytes[](proposal.targets.length);
    for (uint256 i; i < proposal.targets.length; ++i) {
      commandInput[2] = vm.toString(proposal.calldatas[i]);
      decodedCallDatas[i] = vm.ffi(commandInput);
    }

    for (uint256 i; i < proposal.targets.length; ++i) {
      console.log(
        string.concat(
          StdStyle.blue(
            string.concat("\n========================== ", "Index: ", vm.toString(i), " ==========================\n")
          ),
          "Target:      \t",
          vm.getLabel(proposal.targets[i]),
          "\nValue:     \t",
          vm.toString(proposal.values[i]),
          "\nGas amount:\t",
          vm.toString(proposal.gasAmounts[i]),
          "\nCalldata:\n",
          string(decodedCallDatas[i]).yellow()
        )
      );
    }

    console.log(StdStyle.magenta("\n==============================================================================\n"));
  }
}
