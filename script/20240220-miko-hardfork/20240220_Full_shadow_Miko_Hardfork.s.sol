// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./20240220_p1_Miko_before.s.sol";
import "./20240220_p2B_shadow_Miko_propose_proposal.s.sol";
import "./20240220_p4_Miko_after.s.sol";
import "./20240220_p5_Miko_stable.s.sol";

contract Proposal__Full_20240220_MikoHardfork_ProposeProposal is
  Proposal__20240220_MikoHardfork_Before,
  Proposal__20240220_MikoHardfork_ProposeProposal,
  Proposal__20240220_MikoHardfork_After,
  Proposal__20240220_MikoHardfork_Stable
{
  using LibProxy for *;
  using StdStyle for *;
  using ArrayReplaceLib for *;

  modifier resetBroadcastStatus() {
    _;
    CONFIG.setBroadcastDisableStatus(false);
  }

  /**
   * See `README.md`
   */
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
    resetBroadcastStatus
  {
    Proposal__Base_20240220_MikoHardfork.run();

    CONFIG.setBroadcastDisableStatus(false);
    Proposal__20240220_MikoHardfork_Before._run_unchained(); // BAO_EOA

    CONFIG.setBroadcastDisableStatus(true);
    Proposal__20240220_MikoHardfork_ProposeProposal._run_unchained(); // Governor

    CONFIG.setBroadcastDisableStatus(true);
    Proposal__20240220_MikoHardfork_After._run_unchained(); // DOCTOR

    CONFIG.setBroadcastDisableStatus(true);
    Proposal__20240220_MikoHardfork_Stable._run_unchained(); // MIGRATOR
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
