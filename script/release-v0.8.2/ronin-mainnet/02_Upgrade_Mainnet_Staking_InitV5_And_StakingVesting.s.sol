// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninMigration } from "script/RoninMigration.s.sol";
import { IRoninGovernanceAdmin } from "src/interfaces/IRoninGovernanceAdmin.sol";
import { IRoninTrustedOrganization } from "src/interfaces/IRoninTrustedOrganization.sol";
import { StakingVesting } from "src/ronin/StakingVesting.sol";
import { Staking } from "src/ronin/staking/Staking.sol";

import { LibProposal, Proposal } from "script/shared/libraries/LibProposal.sol";
import { Contract } from "script/utils/Contract.sol";
import { Network } from "script/utils/Network.sol";

import {
  TransparentUpgradeableProxy
} from "@openzeppelin-v4/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { console } from "forge-std/console.sol";
import { IStaking } from "src/interfaces/staking/IStaking.sol";

contract Migration_02_Upgrade_Mainnet_Staking_InitV5_And_StakingVesting_Release is RoninMigration {
  Proposal.ProposalDetail internal _proposal;
  IRoninGovernanceAdmin internal _governanceAdmin;
  IRoninTrustedOrganization internal _trustedOrg;

  address constant MIGRATOR = 0x9D05D1F5b0424F8fDE534BC196FFB6Dd211D902a;
  address constant PROPOSER = 0xe880802580a1fbdeF67ACe39D1B21c5b2C74f059;
  uint256 constant EXPIRY = 14 days;

  Staking internal _staking;
  StakingVesting internal _stakingVesting;

  function run() public {
    _staking = Staking(loadContract(Contract.Staking.key()));
    _stakingVesting = StakingVesting(loadContract(Contract.StakingVesting.key()));
    address newStaking = _deployLogic(Contract.Staking.key());
    address newStakingVesting = _deployLogic(Contract.StakingVesting.key());

    address[] memory targets = new address[](2);
    targets[0] = address(_staking);
    targets[1] = address(_stakingVesting);

    bytes[] memory callDatas = new bytes[](2);
    callDatas[0] = abi.encodeCall(
      TransparentUpgradeableProxy.upgradeToAndCall, (newStaking, abi.encodeCall(IStaking.initializeV5, (MIGRATOR)))
    );
    callDatas[1] = abi.encodeCall(
      TransparentUpgradeableProxy.upgradeToAndCall,
      (newStakingVesting, abi.encodeCall(StakingVesting.initializeV5, (address(MIGRATOR), address(_staking))))
    );

    uint256[] memory values = new uint256[](2);

    _governanceAdmin = IRoninGovernanceAdmin(loadContract(Contract.RoninGovernanceAdmin.key()));
    console.log("GovernanceAdmin", address(_governanceAdmin));
    _trustedOrg = IRoninTrustedOrganization(loadContract(Contract.RoninTrustedOrganization.key()));

    _proposal = LibProposal.buildProposal(_governanceAdmin, vm.getBlockTimestamp() + EXPIRY, targets, values, callDatas);
    LibProposal.proposeProposal(_governanceAdmin, _trustedOrg, _proposal, PROPOSER);
  }

  function _postCheck() internal virtual override {
    LibProposal.voteProposalUntilExecute(_governanceAdmin, _trustedOrg, _proposal);

    // Unexpected: Revert if attacker tries to call initializeV5
    address attacker = makeAddr("attacker");
    vm.expectRevert();
    vm.prank(attacker);
    _staking.initializeV5(attacker);

    // Unexpected: Revert if attacker tries to call migrateReward
    vm.expectRevert();
    vm.prank(attacker);
    _stakingVesting.migrateReward(attacker, 1000);

    // Happy path: setL2Migrated should be callable by the migrator
    vm.prank(MIGRATOR);
    _staking.setL2Migrated(true);
    vm.assertEq(_staking.isL2Migrated(), true);

    // Happy path: migrateReward should be callable by the migrator
    address target = makeAddr("target");
    uint256 balanceBefore = address(_stakingVesting).balance;
    vm.prank(MIGRATOR);
    _stakingVesting.migrateReward(target, 1000);

    vm.assertEq(address(_stakingVesting).balance, balanceBefore - 1000);
    vm.assertEq(address(target).balance, 1000);

    super._postCheck();
  }

  //   function _afterRunningScript() internal virtual override { }
}
