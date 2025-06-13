// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";
import { IRoninGovernanceAdmin } from "src/interfaces/IRoninGovernanceAdmin.sol";
import { IRoninTrustedOrganization } from "src/interfaces/IRoninTrustedOrganization.sol";

import { LibProposal, Proposal } from "script/shared/libraries/LibProposal.sol";
import { Contract } from "script/utils/Contract.sol";
import { Network } from "script/utils/Network.sol";

contract Migration_01_Upgrade_TestnetShadow_Release_v0_8_2 is RoninMigration {
  using Proposal for Proposal.ProposalDetail;

  Proposal.ProposalDetail internal _proposal;
  IRoninGovernanceAdmin internal _governanceAdmin;
  IRoninTrustedOrganization internal _trustedOrg;

  function run() public {
    vm.chainId(2021);
    // _deployProxy(Contract.RoninBaseFeeTreasury.key());
    address newStaking = _deployLogic(Contract.Staking.key());
    address newMaintenance = _deployLogic(Contract.Maintenance.key());

    address[] memory targets = new address[](2);
    targets[0] = loadContract(Contract.Staking.key());
    targets[1] = loadContract(Contract.Maintenance.key());

    bytes[] memory callDatas = new bytes[](2);
    callDatas[0] = abi.encodeWithSignature("upgradeTo(address)", newStaking);
    callDatas[1] = abi.encodeWithSignature("upgradeTo(address)", newMaintenance);

    uint256[] memory values = new uint256[](2);

    _governanceAdmin = IRoninGovernanceAdmin(loadContract(Contract.RoninGovernanceAdmin.key()));
    _trustedOrg = IRoninTrustedOrganization(loadContract(Contract.RoninTrustedOrganization.key()));

    _proposal = LibProposal.buildProposal(_governanceAdmin, 1_741_590_095, targets, values, callDatas);
    LibProposal.executeProposal(_governanceAdmin, _trustedOrg, _proposal);
  }

  function _afterRunningScript() internal virtual override { }
}
