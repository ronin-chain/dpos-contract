// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./20240220_p2_Miko_build_proposal.s.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { Contract } from "script/utils/Contract.sol";

contract Proposal__20240220_MikoHardfork_ProposeProposal is Proposal__20240220_MikoHardfork_BuildProposal {
  using LibProxy for *;
  using StdStyle for *;

  /**
   * See `README.md`
   */
  function run() public virtual override onlyOn(DefaultNetwork.RoninMainnet.key()) {
    Proposal__Base_20240220_MikoHardfork.run();

    _run_unchained();
  }

  function _run_unchained() internal virtual {
    Proposal.ProposalDetail memory proposal = _buildFinalProposal();
    LibProposal.proposeProposal(roninGovernanceAdmin, trustedOrgContract, proposal, SKY_MAVIS_GOVERNOR);

    vme.setPostCheckingStatus(true);
    LibProposal.voteProposalUntilExecute(roninGovernanceAdmin, trustedOrgContract, proposal);
    vme.setPostCheckingStatus(false);

    vme.setAddress(network(), Contract.RoninGovernanceAdmin.key(), address(_newGA));
  }
}
