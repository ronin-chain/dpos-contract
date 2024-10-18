// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { Test, console } from "forge-std/Test.sol";
import { IStaking, Staking } from "@ronin/contracts/ronin/staking/Staking.sol";
import { Maintenance } from "@ronin/contracts/ronin/Maintenance.sol";
import { TConsensus, Profile, IProfile } from "@ronin/contracts/ronin/profile/Profile.sol";
import { IRoninValidatorSet } from "@ronin/contracts/interfaces/validator/IRoninValidatorSet.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { LibSharedAddress } from "@fdk/libraries/LibSharedAddress.sol";
import { ISharedArgument } from "script/interfaces/ISharedArgument.sol";
import { DeployDPoS } from "script/deploy-dpos/DeployDPoS.s.sol";
import { Contract } from "script/utils/Contract.sol";
import { LibPrecompile } from "script/shared/libraries/LibPrecompile.sol";

contract MaintenanceTest is Test {
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

    _applyValidatorCandidate();
  }

  function testFuzz_schedule(uint256 index, uint32 durationInBlock) external {
    address[] memory validatorIds = validatorSet.getValidatorIds();
    address validatorId = validatorIds[index % validatorIds.length];

    _schedule(validatorId, durationInBlock);
  }

  function testFuzz_cancelSchedule(
    uint256 index
  ) external {
    address[] memory validatorIds = validatorSet.getValidatorIds();
    address validatorId = validatorIds[index % validatorIds.length];

    IProfile.CandidateProfile memory candidateProfile = profile.getId2Profile(validatorId);
    TConsensus consensus = candidateProfile.consensus;
    address admin = candidateProfile.admin;

    uint256 minOffset = maintenance.minOffsetToStartSchedule();
    uint256 latestEpochBlock = validatorSet.getLastUpdatedBlock();
    uint256 numberOfBlocksInEpoch = validatorSet.numberOfBlocksInEpoch();
    uint256 minDuration = maintenance.minMaintenanceDurationInBlock();
    uint256 maxDuration = maintenance.maxMaintenanceDurationInBlock();

    uint256 durationInBlock = _bound(100, minDuration, maxDuration);

    uint startBlock = latestEpochBlock + numberOfBlocksInEpoch + 1
      + ((minOffset + numberOfBlocksInEpoch) / numberOfBlocksInEpoch) * numberOfBlocksInEpoch;
    uint endBlock = startBlock - 1 + (durationInBlock / numberOfBlocksInEpoch + 1) * numberOfBlocksInEpoch;

    vm.prank(admin);
    maintenance.schedule(consensus, startBlock, endBlock);

    assertTrue(maintenance.checkScheduled(consensus));

    vm.prank(admin);
    maintenance.cancelSchedule(consensus);

    vm.roll(startBlock + 1);
    assertFalse(maintenance.checkScheduled(consensus), "maintenance is still scheduled");
    assertEq(maintenance.totalSchedule(), 0, "total schedule is not 0");
  }

  function testConcrete_CanSchedule_AfterAutoEndSchedules_schedule() external {
    address[] memory validatorIds = validatorSet.getValidatorIds();
    assertEq(validatorIds.length, 4, "validatorIds.length != 4");

    _schedule(validatorIds[0], 100);
    _schedule(validatorIds[1], 200);

    vm.roll(block.number + 20);
    vm.warp(block.timestamp + 60);
    (,,, uint256 end2) = _schedule(validatorIds[2], 300);

    vm.roll(end2 + 1);
    vm.warp(block.timestamp + (end2 + 1) * 3);
    _wrapUpEpoch();

    _fastForwardToNextDay();
    _wrapUpEpoch();
    assertEq(maintenance.totalSchedule(), 0, "total schedule is not 0");

    _schedule(validatorIds[3], 300);

    assertEq(maintenance.totalSchedule(), 1, "total schedule is not 1");
  }

  function testConcrete_totalSchedule() external {
    assertEq(maintenance.totalSchedule(), 0);

    address[] memory validatorIds = validatorSet.getValidatorIds();

    (address admin0, TConsensus consensus0, uint256 start0,) = _schedule(validatorIds[0], 100);

    vm.roll(block.number + 10);
    vm.warp(block.timestamp + 30);
    (address admin1, TConsensus consensus1, uint256 start1,) = _schedule(validatorIds[1], 200);

    vm.roll(block.number + 20);
    vm.warp(block.timestamp + 60);
    (, TConsensus consensus2,, uint256 end2) = _schedule(validatorIds[2], 300);

    assertEq(maintenance.totalSchedule(), 3);

    vm.roll(start0);
    vm.prank(admin0);
    maintenance.exitMaintenance(consensus0);

    vm.roll(start0 + 1);
    assertFalse(maintenance.checkScheduled(consensus0), "maintenance is still scheduled");
    assertEq(maintenance.totalSchedule(), 2, "total schedule is not 2");

    vm.roll(start1);
    vm.prank(admin1);
    maintenance.exitMaintenance(consensus1);

    vm.roll(start1 + 1);
    assertFalse(maintenance.checkScheduled(consensus1), "maintenance is still scheduled");
    assertEq(maintenance.totalSchedule(), 1, "total schedule is not 1");

    vm.roll(end2 + 1);
    assertFalse(maintenance.checkScheduled(consensus2), "maintenance is still scheduled");
    assertEq(maintenance.totalSchedule(), 0, "total schedule is not 0");
  }

  function _schedule(
    address validatorId,
    uint256 durationInBlock
  ) private returns (address admin, TConsensus consensus, uint256 startBlock, uint256 endBlock) {
    uint256 totalSchedule = maintenance.totalSchedule();
    IProfile.CandidateProfile memory candidateProfile = profile.getId2Profile(validatorId);
    consensus = candidateProfile.consensus;
    admin = candidateProfile.admin;

    console.log("admin", admin);
    console.log("consensus", TConsensus.unwrap(consensus));

    uint256 minOffset = maintenance.minOffsetToStartSchedule();
    uint256 latestEpochBlock = validatorSet.getLastUpdatedBlock();
    uint256 numberOfBlocksInEpoch = validatorSet.numberOfBlocksInEpoch();
    uint256 minDuration = maintenance.minMaintenanceDurationInBlock();
    uint256 maxDuration = maintenance.maxMaintenanceDurationInBlock();

    console.log("minDuration", minDuration);
    console.log("maxDuration", maxDuration);

    durationInBlock = _bound(durationInBlock, minDuration, maxDuration);

    startBlock = latestEpochBlock + numberOfBlocksInEpoch + 1
      + ((minOffset + numberOfBlocksInEpoch) / numberOfBlocksInEpoch) * numberOfBlocksInEpoch;
    endBlock = startBlock - 1 + ((durationInBlock / numberOfBlocksInEpoch + 1) * numberOfBlocksInEpoch);

    console.log("startBlock", startBlock);
    console.log("endBlock", endBlock);

    vm.prank(admin);
    maintenance.schedule(consensus, startBlock, endBlock);

    assertTrue(maintenance.checkScheduled(consensus));
    assertEq(maintenance.totalSchedule(), totalSchedule + 1);
  }

  function testFuzz_exitMaintenance(
    uint256 index
  ) external {
    address[] memory validatorIds = validatorSet.getValidatorIds();
    console.log("validatorIds.length", validatorIds.length);
    address validatorId = validatorIds[index == 0 ? 0 : index % validatorIds.length];

    IProfile.CandidateProfile memory candidateProfile = profile.getId2Profile(validatorId);
    TConsensus consensus = candidateProfile.consensus;
    address admin = candidateProfile.admin;

    uint256 minOffset = maintenance.minOffsetToStartSchedule();
    uint256 latestEpochBlock = validatorSet.getLastUpdatedBlock();
    uint256 numberOfBlocksInEpoch = validatorSet.numberOfBlocksInEpoch();
    uint256 minDuration = maintenance.minMaintenanceDurationInBlock();

    uint startBlock = latestEpochBlock + numberOfBlocksInEpoch + 1
      + ((minOffset + numberOfBlocksInEpoch) / numberOfBlocksInEpoch) * numberOfBlocksInEpoch;
    uint endBlock = startBlock - 1 + (minDuration / numberOfBlocksInEpoch + 1) * numberOfBlocksInEpoch;

    vm.prank(admin);
    maintenance.schedule(consensus, startBlock, endBlock);

    assertTrue(maintenance.checkScheduled(consensus));

    vm.roll(startBlock);
    vm.prank(admin);
    maintenance.exitMaintenance(consensus);

    vm.roll(startBlock + 1);
    assertFalse(maintenance.checkScheduled(consensus), "maintenance is still scheduled");
    assertEq(maintenance.totalSchedule(), 0, "total schedule is not 0");
  }

  function _applyValidatorCandidate(address candidateAdmin, TConsensus consensusAddr, uint256 value) internal {
    vm.deal(candidateAdmin, value);
    vm.startPrank(candidateAdmin);

    IStaking(address(staking)).applyValidatorCandidate{ value: value }(
      candidateAdmin,
      consensusAddr,
      payable(candidateAdmin),
      15_00,
      bytes(string.concat("mock-pub-key", vm.toString(candidateAdmin))),
      bytes(string.concat("mock-proof-of-possession", vm.toString(candidateAdmin)))
    );

    vm.stopPrank();
  }

  function _applyValidatorCandidate() private {
    address candidateAdmin = makeAddr("mock-candidate-admin-t1111");
    TConsensus consensusAddr = TConsensus.wrap(makeAddr("mock-consensus-addr-t1111"));

    _applyValidatorCandidate(candidateAdmin, consensusAddr, 1000 ether);

    _fastForwardToNextDay();
    _wrapUpEpoch();

    assertTrue(validatorSet.isValidatorCandidate(consensusAddr));

    candidateAdmin = makeAddr("mock-candidate-admin-t2");
    consensusAddr = TConsensus.wrap(makeAddr("mock-consensus-addr-t2"));

    _applyValidatorCandidate(candidateAdmin, consensusAddr, 1000 ether);

    assertTrue(validatorSet.isValidatorCandidate(consensusAddr));

    _fastForwardToNextDay();
    _wrapUpEpoch();

    candidateAdmin = makeAddr("mock-candidate-admin-t3");
    consensusAddr = TConsensus.wrap(makeAddr("mock-consensus-addr-t3"));

    _applyValidatorCandidate(candidateAdmin, consensusAddr, 1000 ether);

    assertTrue(validatorSet.isValidatorCandidate(consensusAddr));

    _fastForwardToNextDay();
    _wrapUpEpoch();

    candidateAdmin = makeAddr("mock-candidate-admin-t4444");
    consensusAddr = TConsensus.wrap(makeAddr("mock-consensus-addr-t4444"));

    _applyValidatorCandidate(candidateAdmin, consensusAddr, 1000 ether);

    assertTrue(validatorSet.isValidatorCandidate(consensusAddr));

    _fastForwardToNextDay();
    _wrapUpEpoch();
  }

  function _wrapUpEpochs(
    uint256 times
  ) internal {
    for (uint256 i; i < times; ++i) {
      _fastForwardToNextDay();
      _wrapUpEpoch();
    }
  }

  function _wrapUpEpoch() internal {
    _wrapUpEpoch(block.coinbase);
  }

  function _wrapUpEpoch(
    address caller
  ) internal {
    vm.startPrank(caller);
    try validatorSet.wrapUpEpoch() { } catch { }
    vm.stopPrank();
  }

  function _fastForwardToNextEpoch() internal {
    vm.warp(block.timestamp + 3 seconds);
    vm.roll(block.number + 1);

    uint256 numberOfBlocksInEpoch = validatorSet.numberOfBlocksInEpoch();
    uint256 epochEndingBlockNumber = block.number + (numberOfBlocksInEpoch - 1) - (block.number % numberOfBlocksInEpoch);

    vm.roll(epochEndingBlockNumber);
  }

  function _fastForwardToNextDay() internal {
    _fastForwardToNextEpoch();

    uint256 nextDayTimestamp = block.timestamp + 1 days;
    vm.warp(nextDayTimestamp);
  }
}
