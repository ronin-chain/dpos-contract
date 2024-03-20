// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./20240220_p2_Miko_build_proposal.s.sol";

contract Proposal__20240220_MikoHardfork_ChangeAllAdmins is Proposal__20240220_MikoHardfork_BuildProposal {
  using LibProxy for *;
  using StdStyle for *;
  using ArrayReplaceLib for *;

  /**
   * See `README.md`
   */
  function run() public virtual override onlyOn(DefaultNetwork.RoninMainnet.key()) {
    Proposal__Base_20240220_MikoHardfork.run();

    _run_unchained();
  }

  function _run_unchained() internal virtual {
    Proposal.ProposalDetail memory proposal = _buildChangeAdminsProposal();
    _proposeProposal(roninGovernanceAdmin, trustedOrgContract, proposal, address(0));
    _voteProposalUntilSuccess(roninGovernanceAdmin, trustedOrgContract, proposal);

    CONFIG.setAddress(network(), Contract.RoninGovernanceAdmin.key(), address(_newGA));
  }

  function _buildChangeAdminsProposal() internal returns (Proposal.ProposalDetail memory proposal) {
    address[] memory tos = new address[](40);
    bytes[] memory callDatas = new bytes[](40);
    uint256[] memory values = new uint256[](40);
    uint prCnt;

    // [B5.] Change admin of all contracts
    {
      (bytes[] memory sub_callDatas, address[] memory sub_targets, uint256[] memory sub_values) =
        _ga__changeAdminAllContracts();

      tos = tos.replace(sub_targets, prCnt);
      callDatas = callDatas.replace(sub_callDatas, prCnt);
      values = values.replace(sub_values, prCnt);
      prCnt += sub_callDatas.length;
    }

    // [Build proposal]
    assembly {
      mstore(tos, prCnt)
      mstore(callDatas, prCnt)
      mstore(values, prCnt)
    }

    proposal = _buildProposal(roninGovernanceAdmin, block.timestamp + PROPOSAL_DURATION, tos, values, callDatas);
  }
}
