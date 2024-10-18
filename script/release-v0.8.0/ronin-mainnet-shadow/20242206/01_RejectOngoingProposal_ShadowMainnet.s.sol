// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";
import { LibWrapUpEpoch } from "script/shared/libraries/LibWrapUpEpoch.sol";
import { Proposal } from "src/libraries/Proposal.sol";
import { IRoninGovernanceAdmin } from "src/interfaces/IRoninGovernanceAdmin.sol";
import { IRoninTrustedOrganization } from "src/interfaces/IRoninTrustedOrganization.sol";
import { LibPrecompile } from "script/shared/libraries/LibPrecompile.sol";
import { Contract } from "script/utils/Contract.sol";

contract Migration__01_RejectOnGoingProposal_ShadowMainnet is RoninMigration {
  address[] _targets;
  bytes[] _calldatas;
  uint256[] _values;
  uint256[] _gasAmounts;

  function run() external {
    vm.chainId(2020);
    _targets = [
      0xA30B2932CD8b8A89E34551Cdfa13810af38dA576,
      0x6F45C1f8d84849D497C6C0Ac4c3842DC82f49894,
      0x840EBf1CA767CB690029E91856A357a43B85d035,
      0x98D0230884448B3E2f09a177433D60fb1E19C090,
      0x617c5d73662282EA7FfD231E020eCa6D2B0D552f,
      0xEBFFF2b32fA0dF9C5C8C5d5AAa7e8b51d5207bA3,
      0x545edb750eB8769C868429BE9586F5857A768758,
      0xC768423A2AE2B5024cB58F3d6449A8f5DB6D8816,
      0x617c5d73662282EA7FfD231E020eCa6D2B0D552f
    ];
    _values = [0, 0, 0, 0, 0, 0, 0, 0, 0];
    _gasAmounts = [
      uint256(0xf4240),
      uint256(0xf4240),
      uint256(0xf4240),
      uint256(0xf4240),
      uint256(0xf4240),
      uint256(0xf4240),
      uint256(0xf4240),
      uint256(0xf4240),
      uint256(0xf4240)
    ];

    _calldatas = [
      bytes(
        hex"4f1ef286000000000000000000000000a5ac7555d34cb77585dab49ad6ae12827298fed0000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000243101cfcb000000000000000000000000545edb750eb8769c868429be9586f5857a76875800000000000000000000000000000000000000000000000000000000"
      ),
      bytes(hex"3659cfe60000000000000000000000003e07aeeef99a1f6ebc9b236b8b0051ac18560a48"),
      bytes(hex"3659cfe6000000000000000000000000f2686639c1c8d291059eb19ab3c5e75683e50ad2"),
      bytes(hex"3659cfe600000000000000000000000083246543dfc871f078ed7cffca97095db85da08d"),
      bytes(
        hex"4f1ef2860000000000000000000000001c327065568622bec442272c6d8c822575208ddc00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000024c4d66de8000000000000000000000000ae4788294759c1ea2d095766cc902786ba2280dc00000000000000000000000000000000000000000000000000000000"
      ),
      bytes(
        hex"4f1ef286000000000000000000000000d503747234cd3179508831de24be8990f50ebfc80000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000006403933804000000000000000000000000ae4788294759c1ea2d095766cc902786ba2280dc00000000000000000000000000000000000000000000003635c9adc5dea000000000000000000000000000000000000000000000000000000000000000004dc400000000000000000000000000000000000000000000000000000000"
      ),
      bytes(hex"3659cfe6000000000000000000000000b7161757c02a6f71361c38f7022876105b266fdc"),
      bytes(hex"3659cfe6000000000000000000000000b63cc4b6a8ad9690d7d50bbd937622932ca2e779"),
      bytes(
        hex"4bb5274a000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000244f2a693f000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000"
      )
    ];
    Proposal.ProposalDetail memory proposal = Proposal.ProposalDetail({
      nonce: 2,
      chainId: 2020,
      expiryTimestamp: 1_719_896_988,
      targets: _targets,
      values: _values,
      calldatas: _calldatas,
      gasAmounts: _gasAmounts
    });

    IRoninGovernanceAdmin governanceAdmin = IRoninGovernanceAdmin(loadContract(Contract.RoninGovernanceAdmin.key()));
    IRoninTrustedOrganization trustedOrganization =
      IRoninTrustedOrganization(loadContract(Contract.RoninTrustedOrganization.key()));

    LibProposal.voteProposalUntilReject(governanceAdmin, trustedOrganization, proposal);
  }
}
