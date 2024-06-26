// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Proposal__Base_20240220_MikoHardfork } from "./20240220_Base_Miko_Hardfork.s.sol";
import { Proposal__20240220_MikoHardfork_Before } from "./20240220_p1_Miko_before.s.sol";
import { Proposal__20240220_MikoHardfork_ProposeProposal } from "./20240220_p2A_mainnet_Miko_propose_proposal.s.sol";
import { Proposal__20240220_MikoHardfork_After } from "./20240220_p4_Miko_after.s.sol";
import { Proposal__20240220_MikoHardfork_Stable } from "./20240220_p5_Miko_stable.s.sol";
import { Proposal__20240220_PostCheck } from "./20240220_p6_postcheck.s.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";

contract Proposal__Full_20240220_MikoHardfork_ProposeProposal is
  Proposal__20240220_MikoHardfork_Before,
  Proposal__20240220_MikoHardfork_ProposeProposal,
  Proposal__20240220_MikoHardfork_After,
  Proposal__20240220_MikoHardfork_Stable,
  Proposal__20240220_PostCheck
{
  modifier resetBroadcastStatus() {
    _;
    vme.setPostCheckingStatus(false);
  }

  function run()
    public
    virtual
    override(
      Proposal__20240220_MikoHardfork_Before,
      Proposal__20240220_MikoHardfork_ProposeProposal,
      Proposal__20240220_MikoHardfork_After,
      Proposal__20240220_MikoHardfork_Stable,
      Proposal__20240220_PostCheck
    )
    onlyOn(DefaultNetwork.RoninMainnet.key())
    resetBroadcastStatus
  {
    Proposal__Base_20240220_MikoHardfork.run();

    // vme.setPostCheckingStatus(true);
    // Proposal__20240220_MikoHardfork_Before._run_unchained(); // BAO_EOA

    // vme.setPostCheckingStatus(false);
    // Proposal__20240220_MikoHardfork_ProposeProposal._run_unchained(); // Governor

    vme.setPostCheckingStatus(false);
    Proposal__20240220_MikoHardfork_After._run_unchained(); // DOCTOR

    vme.setPostCheckingStatus(true);
    Proposal__20240220_MikoHardfork_Stable._run_unchained(); // MIGRATOR

    Proposal__20240220_PostCheck._run_unchained();
  }

  function _run_unchained()
    internal
    override(
      Proposal__20240220_MikoHardfork_Before,
      Proposal__20240220_MikoHardfork_ProposeProposal,
      Proposal__20240220_MikoHardfork_After,
      Proposal__20240220_MikoHardfork_Stable,
      Proposal__20240220_PostCheck
    )
  { }
}
