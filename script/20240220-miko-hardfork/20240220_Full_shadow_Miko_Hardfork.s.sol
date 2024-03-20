// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./20240220_p1_Miko_before.s.sol";
import "./20240220_p2B_shadow_Miko_propose_proposal.s.sol";
import "./20240220_p4_Miko_after.s.sol";
import "./20240220_p5_Miko_stable.s.sol";
import "./20240220_p6_postcheck.s.sol";

contract Proposal__Full_20240220_MikoHardfork_ProposeProposal is
  Proposal__20240220_MikoHardfork_Before,
  Proposal__20240220_MikoHardfork_ProposeProposal,
  Proposal__20240220_MikoHardfork_After,
  Proposal__20240220_MikoHardfork_Stable,
  Proposal__20240220_PostCheck
{
  using LibProxy for *;
  using StdStyle for *;
  using ArrayReplaceLib for *;

  modifier resetBroadcastStatus() {
    _;
    CONFIG.setPostCheckingStatus(false);
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
      Proposal__20240220_MikoHardfork_Stable,
      Proposal__20240220_PostCheck
    )
    onlyOn(DefaultNetwork.RoninMainnet.key())
    resetBroadcastStatus
  {
    Proposal__Base_20240220_MikoHardfork.run();

    vm.startPrank(DEPLOYER);
    payable(0x529502C69356E9f48C8D5427B030020941F9ef42).transfer(10 ether);
    payable(0x85C5dBfadcBc36AeE39DD32365183c5E38A67E37).transfer(10 ether);
    payable(0x947AB99ad90302b5ec1840c9b5CF4205554C72af).transfer(10 ether);
    payable(0x6a0397bDF0275Ad0201174afc05D3CFa27A5e1f1).transfer(10 ether);
    payable(0x96262418638f93119429b8824fc22DFe7f428063).transfer(10 ether);
    payable(0x32dA26032Ef488Ffe7d5A4Af23FD3bbBbCacA4C7).transfer(10 ether);
    vm.stopPrank();

    // CONFIG.setBroadcastDisableStatus(true);
    // Proposal__20240220_MikoHardfork_Before._run_unchained(); // BAO_EOA

    // CONFIG.setBroadcastDisableStatus(false);
    // Proposal__20240220_MikoHardfork_ProposeProposal._run_unchained(); // Governor

    // CONFIG.setBroadcastDisableStatus(false);
    // Proposal__20240220_MikoHardfork_After._run_unchained(); // DOCTOR

    CONFIG.setPostCheckingStatus(false);
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
