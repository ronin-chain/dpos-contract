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

import { IAccessControl } from "@openzeppelin-v4/contracts/access/IAccessControl.sol";
import {
  TransparentUpgradeableProxy
} from "@openzeppelin-v4/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { console } from "forge-std/console.sol";
import { IStaking } from "src/interfaces/staking/IStaking.sol";
import { RoninValidatorSet } from "src/ronin/validator/RoninValidatorSet.sol";

contract Migration_02_Upgrade_Mainnet_Staking_InitV5_And_StakingVesting_InitV5_And_ChangeAdmin is RoninMigration {
  Proposal.ProposalDetail internal _proposal;
  IRoninGovernanceAdmin internal _governanceAdmin;
  IRoninTrustedOrganization internal _trustedOrg;

  bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;
  address constant MULTISIG_ADMIN = 0xFE997edB76dE3bc8C85bfB56Cff6B97D8aa2e400;
  address constant MIGRATOR = 0x9D05D1F5b0424F8fDE534BC196FFB6Dd211D902a;
  address constant PROPOSER = 0xe880802580a1fbdeF67ACe39D1B21c5b2C74f059;
  uint256 constant EXPIRY = 14 days;

  Staking internal _staking;
  StakingVesting internal _stakingVesting;
  RoninValidatorSet internal _roninValidatorSet;

  function run() public {
    _staking = Staking(loadContract(Contract.Staking.key()));
    _stakingVesting = StakingVesting(loadContract(Contract.StakingVesting.key()));
    _roninValidatorSet = RoninValidatorSet(loadContract(Contract.RoninValidatorSet.key()));
    address newStaking = _deployLogic(Contract.Staking.key());
    address newStakingVesting = _deployLogic(Contract.StakingVesting.key());
    address newRoninValidatorSet = _deployLogic(Contract.RoninValidatorSet.key());

    address[] memory targets = new address[](13);
    targets[0] = address(_staking);
    targets[1] = address(_stakingVesting);
    targets[2] = address(_roninValidatorSet);
    targets[3] = address(_staking);
    targets[4] = address(_staking);
    targets[5] = address(_stakingVesting);
    targets[6] = address(_roninValidatorSet);
    targets[7] = loadContract(Contract.RoninRandomBeacon.key());
    targets[8] = loadContract(Contract.FastFinalityTracking.key());
    targets[9] = loadContract(Contract.RoninTrustedOrganization.key());
    targets[10] = loadContract(Contract.Maintenance.key());
    targets[11] = loadContract(Contract.SlashIndicator.key());
    targets[12] = loadContract(Contract.Profile.key());

    bytes[] memory callDatas = new bytes[](13);
    callDatas[0] = abi.encodeCall(
      TransparentUpgradeableProxy.upgradeToAndCall, (newStaking, abi.encodeCall(IStaking.initializeV5, (MIGRATOR)))
    );
    callDatas[1] = abi.encodeCall(
      TransparentUpgradeableProxy.upgradeToAndCall,
      (newStakingVesting, abi.encodeCall(StakingVesting.initializeV5, (address(MIGRATOR), address(_staking))))
    );
    callDatas[2] = abi.encodeCall(TransparentUpgradeableProxy.upgradeTo, (newRoninValidatorSet));
    callDatas[3] = abi.encodeCall(TransparentUpgradeableProxy.changeAdmin, (MULTISIG_ADMIN));
    callDatas[4] = abi.encodeCall(IAccessControl.grantRole, (DEFAULT_ADMIN_ROLE, MULTISIG_ADMIN));
    callDatas[5] = abi.encodeCall(TransparentUpgradeableProxy.changeAdmin, (MULTISIG_ADMIN));
    callDatas[6] = abi.encodeCall(TransparentUpgradeableProxy.changeAdmin, (MULTISIG_ADMIN));
    callDatas[7] = abi.encodeCall(TransparentUpgradeableProxy.changeAdmin, (MULTISIG_ADMIN));
    callDatas[8] = abi.encodeCall(TransparentUpgradeableProxy.changeAdmin, (MULTISIG_ADMIN));
    callDatas[9] = abi.encodeCall(TransparentUpgradeableProxy.changeAdmin, (MULTISIG_ADMIN));
    callDatas[10] = abi.encodeCall(TransparentUpgradeableProxy.changeAdmin, (MULTISIG_ADMIN));
    callDatas[11] = abi.encodeCall(TransparentUpgradeableProxy.changeAdmin, (MULTISIG_ADMIN));
    callDatas[12] = abi.encodeCall(TransparentUpgradeableProxy.changeAdmin, (MULTISIG_ADMIN));

    uint256[] memory values = new uint256[](13);

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
