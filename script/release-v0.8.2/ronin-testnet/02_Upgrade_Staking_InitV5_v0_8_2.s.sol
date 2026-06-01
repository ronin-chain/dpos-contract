// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninMigration } from "script/RoninMigration.s.sol";
import { IRoninGovernanceAdmin } from "src/interfaces/IRoninGovernanceAdmin.sol";
import { IRoninTrustedOrganization } from "src/interfaces/IRoninTrustedOrganization.sol";
import { Staking } from "src/ronin/staking/Staking.sol";

import { LibProposal, Proposal } from "script/shared/libraries/LibProposal.sol";
import { Contract } from "script/utils/Contract.sol";
import { Network } from "script/utils/Network.sol";

contract Migration_02_Upgrade_Staking_InitV5_Release_v0_8_2 is RoninMigration {
  Proposal.ProposalDetail internal _proposal;
  IRoninGovernanceAdmin internal _governanceAdmin;
  IRoninTrustedOrganization internal _trustedOrg;

  function run() public {
    address migrator = sender();
    address newStaking = _deployLogic(Contract.Staking.key());
    Staking staking = Staking(loadContract(Contract.Staking.key()));

    address[] memory targets = new address[](1);
    targets[0] = loadContract(Contract.Staking.key());

    bytes[] memory callDatas = new bytes[](1);
    callDatas[0] = abi.encodeWithSignature(
      "upgradeToAndCall(address,bytes)", newStaking, abi.encodeWithSignature("initializeV5(address)", migrator)
    );

    uint256[] memory values = new uint256[](1);

    _governanceAdmin = IRoninGovernanceAdmin(loadContract(Contract.RoninGovernanceAdmin.key()));
    _trustedOrg = IRoninTrustedOrganization(loadContract(Contract.RoninTrustedOrganization.key()));

    _proposal =
      LibProposal.buildProposal(_governanceAdmin, vm.getBlockTimestamp() + 1 hours, targets, values, callDatas);
    LibProposal.executeProposal(_governanceAdmin, _trustedOrg, _proposal);

    vm.broadcast(migrator);
    staking.setL2Migrated(true);
  }

  function _afterRunningScript() internal virtual override { }
}
