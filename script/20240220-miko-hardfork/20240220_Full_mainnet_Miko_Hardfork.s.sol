// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./20240220_p1_Miko_before.s.sol";
import "./20240220_p2A_mainnet_Miko_propose_proposal.s.sol";
import "./20240220_p4_Miko_after.s.sol";
import "./20240220_p5_Miko_stable.s.sol";

contract Proposal__Full_20240220_MikoHardfork_ProposeProposal is
  Proposal__20240220_MikoHardfork_Before,
  Proposal__20240220_MikoHardfork_ProposeProposal,
  Proposal__20240220_MikoHardfork_After,
  Proposal__20240220_MikoHardfork_Stable
{
  function run()
    public
    virtual
    override(
      Proposal__20240220_MikoHardfork_Before,
      Proposal__20240220_MikoHardfork_ProposeProposal,
      Proposal__20240220_MikoHardfork_After,
      Proposal__20240220_MikoHardfork_Stable
    )
    onlyOn(DefaultNetwork.RoninMainnet.key())
  {
    Proposal__Base_20240220_MikoHardfork.run();
    Proposal__20240220_MikoHardfork_Before._run_unchained();
    Proposal__20240220_MikoHardfork_ProposeProposal._run_unchained();
    Proposal__20240220_MikoHardfork_After._run_unchained();
    Proposal__20240220_MikoHardfork_Stable._run_unchained();
  }

  function _run_unchained()
    internal
    override(
      Proposal__20240220_MikoHardfork_Before,
      Proposal__20240220_MikoHardfork_ProposeProposal,
      Proposal__20240220_MikoHardfork_After,
      Proposal__20240220_MikoHardfork_Stable
    )
  {}
}
