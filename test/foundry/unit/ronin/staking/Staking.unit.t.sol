// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { LibSharedAddress } from "@fdk/libraries/LibSharedAddress.sol";
import { Test, console } from "forge-std/Test.sol";

import { DeployDPoS } from "script/deploy-dpos/DeployDPoS.s.sol";
import { ISharedArgument } from "script/interfaces/ISharedArgument.sol";

import { LibApplyCandidate } from "script/shared/libraries/LibApplyCandidate.sol";
import { LibPrecompile } from "script/shared/libraries/LibPrecompile.sol";
import { Contract } from "script/utils/Contract.sol";
import { TransparentUpgradeableProxyV2 } from "src/extensions/TransparentUpgradeableProxyV2.sol";

import { ICandidateStaking } from "src/interfaces/staking/ICandidateStaking.sol";
import { IRoninValidatorSet } from "src/interfaces/validator/IRoninValidatorSet.sol";
import { Maintenance } from "src/ronin/Maintenance.sol";
import { IProfile, Profile, TConsensus } from "src/ronin/profile/Profile.sol";
import { IStaking, Staking } from "src/ronin/staking/Staking.sol";

import { StakingCallback } from "src/ronin/staking/StakingCallback.sol";
import { TConsensus } from "src/udvts/Types.sol";

contract StakingTest is Test {
  address coinbase;
  Profile profile;
  Staking staking;
  Maintenance maintenance;
  IRoninValidatorSet validatorSet;
  ISharedArgument config = ISharedArgument(LibSharedAddress.VME);

  function setUp() public {
    coinbase = makeAddr("coinbase");
    vm.coinbase(coinbase);

    vm.roll(block.number + 1000);
    vm.warp(block.timestamp + 3000);

    DeployDPoS dposDeployHelper = new DeployDPoS();
    dposDeployHelper.setUp();
    dposDeployHelper.run();
    LibPrecompile.deployPrecompile();
    dposDeployHelper.cheatSetUpValidators();

    profile = Profile(config.getAddressFromCurrentNetwork(Contract.Profile.key()));
    staking = Staking(config.getAddressFromCurrentNetwork(Contract.Staking.key()));
    maintenance = Maintenance(config.getAddressFromCurrentNetwork(Contract.Maintenance.key()));
    validatorSet = IRoninValidatorSet(config.getAddressFromCurrentNetwork(Contract.RoninValidatorSet.key()));

    vm.warp(vm.unixTime() / 1000);
  }

  function testConcrete_RevertIf_WhenChangeAdminAddr_ImmediateUnstake() external {
    address admin = makeAddr("admin");
    address consensus = makeAddr("consensus");

    LibApplyCandidate.applyValidatorCandidate(address(staking), admin, consensus);
    deal(admin, 2000 ether);
    vm.prank(admin);
    staking.stake{ value: 2000 ether }(TConsensus.wrap(consensus));

    address newAdmin = makeAddr("new-admin");

    vm.prank(admin);
    profile.changeAdminAddr(consensus, newAdmin);

    vm.prank(newAdmin);
    vm.expectRevert(ICandidateStaking.ErrUnstakeTooEarly.selector);
    staking.unstake(TConsensus.wrap(consensus), 1 ether);
  }

  function testConcrete_RevertIf_ChangeAdminAddr_IntoDelegator() external {
    address admin = makeAddr("admin");
    address consensus = makeAddr("consensus");
    address delegator = makeAddr("delegator");

    LibApplyCandidate.applyValidatorCandidate(address(staking), admin, consensus);

    deal(delegator, 100 ether);
    vm.prank(delegator);
    staking.delegate{ value: 100 ether }(TConsensus.wrap(consensus));

    vm.prank(admin);
    vm.expectRevert(abi.encodeWithSelector(StakingCallback.ErrAlreadyDelegator.selector));
    profile.changeAdminAddr(consensus, delegator);
  }

  function testConcrete_ChangeAdminAddr() external {
    address admin = makeAddr("admin");
    address consensus = makeAddr("consensus");

    LibApplyCandidate.applyValidatorCandidate(address(staking), admin, consensus);

    address newAdmin = makeAddr("new-admin");

    vm.prank(admin);
    profile.changeAdminAddr(consensus, newAdmin);

    (address adminAddr,,) = staking.getPoolDetail(TConsensus.wrap(consensus));
    assertEq(adminAddr, newAdmin, "!newAdmin");
  }
}
