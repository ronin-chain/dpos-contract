// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { Test, console } from "forge-std/Test.sol";
import { IStaking, Staking } from "@ronin/contracts/ronin/staking/Staking.sol";
import { Maintenance, IMaintenance } from "@ronin/contracts/ronin/Maintenance.sol";
import { TConsensus, Profile, IProfile } from "@ronin/contracts/ronin/profile/Profile.sol";
import { IRoninValidatorSet } from "@ronin/contracts/interfaces/validator/IRoninValidatorSet.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { LibSharedAddress } from "@fdk/libraries/LibSharedAddress.sol";
import { ISharedArgument } from "script/interfaces/ISharedArgument.sol";
import { DeployDPoS } from "script/deploy-dpos/DeployDPoS.s.sol";
import { Contract } from "script/utils/Contract.sol";
import { LibPrecompile } from "script/shared/libraries/LibPrecompile.sol";
import { ContractType } from "@ronin/contracts/utils/ContractType.sol";
import { IHasContracts } from "@ronin/contracts/interfaces/collections/IHasContracts.sol";
import { ISlashingExecution } from "@ronin/contracts/interfaces/validator/ISlashingExecution.sol";

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

  function testFuzz_cancelSchedule(uint256 index) external {
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

  function testConcrete_ThreeMaintenanceSlots_AtTheSameTime() external {
    address[] memory validatorIds = validatorSet.getValidatorIds();

    // Before maintenance
    assertEq(
      maintenance.checkScheduled(TConsensus.wrap(validatorIds[0])), false, "validator 0 should not be in maintenance"
    );
    assertEq(
      maintenance.checkScheduled(TConsensus.wrap(validatorIds[1])), false, "validator 1 should not be in maintenance"
    );
    assertEq(
      maintenance.checkScheduled(TConsensus.wrap(validatorIds[2])), false, "validator 2 should not be in maintenance"
    );

    // Schedule maintenance for 3 validators
    (,, uint256 start1, uint256 end1) = _schedule(validatorIds[0], 100);
    (,, uint256 start2, uint256 end2) = _schedule(validatorIds[1], 100);
    (,, uint256 start3, uint256 end3) = _schedule(validatorIds[2], 100);
    assertEq(maintenance.totalSchedule(), 3, "total schedule should be 3");
    assertEq(start1, start2, "start1 should be equal to start2");
    assertEq(start1, start3, "start1 should be equal to start3");
    assertEq(end1, end2, "end1 should be equal to end2");
    assertEq(end1, end3, "end1 should be equal to end3");

    // During maintenance
    vm.roll(start1 + 1);
    assertTrue(maintenance.checkScheduled(TConsensus.wrap(validatorIds[0])), "validator 0 should be in maintenance");
    assertTrue(maintenance.checkScheduled(TConsensus.wrap(validatorIds[1])), "validator 1 should be in maintenance");
    assertTrue(maintenance.checkScheduled(TConsensus.wrap(validatorIds[2])), "validator 2 should be in maintenance");

    // After maintenance
    vm.roll(end1 + 1);
    assertFalse(
      maintenance.checkScheduled(TConsensus.wrap(validatorIds[0])), "validator 0 should not be in maintenance"
    );
    assertFalse(
      maintenance.checkScheduled(TConsensus.wrap(validatorIds[1])), "validator 1 should not be in maintenance"
    );
    assertFalse(
      maintenance.checkScheduled(TConsensus.wrap(validatorIds[2])), "validator 2 should not be in maintenance"
    );
  }

  function testRevert_TotalScheduleExceeded() external {
    address[] memory validatorIds = validatorSet.getValidatorIds();
    // Schedule maintenance for 3 validators
    (,, uint256 start1, uint256 end1) = _schedule(validatorIds[0], 100);
    (,, uint256 start2, uint256 end2) = _schedule(validatorIds[1], 200);
    (,, uint256 start3, uint256 end3) = _schedule(validatorIds[2], 300);
    assertEq(maintenance.totalSchedule(), 3, "total schedule should be 3");

    // Attempt to schedule a 4th maintenance
    address admin = profile.getId2Profile(validatorIds[3]).admin;
    TConsensus consensus = profile.getId2Profile(validatorIds[3]).consensus;
    uint256 startAt = block.number + maintenance.minOffsetToStartSchedule();
    uint256 endAt = startAt + maintenance.minMaintenanceDurationInBlock();

    vm.expectRevert(IMaintenance.ErrTotalOfSchedulesExceeded.selector);
    vm.prank(admin);
    maintenance.schedule(consensus, startAt, endAt);
  }

  function testConcrete_BlockProducer_CanSchedule() external {
    address blockProducers = validatorSet.getBlockProducerIds()[0];

    IProfile.CandidateProfile memory candidateProfile = profile.getId2Profile(blockProducers);
    address admin = candidateProfile.admin;
    TConsensus consensus = candidateProfile.consensus;
    assertTrue(validatorSet.isBlockProducer(candidateProfile.consensus));

    // Before maintenance
    assertFalse(maintenance.checkScheduled(consensus), "Should not be in maintenance before start");

    (,, uint256 start, uint256 end) = _schedule(blockProducers, 300);

    // During maintenance
    vm.roll(start + 10);
    assertTrue(maintenance.checkScheduled(consensus), "Should be in maintenance");

    // After maintenance
    vm.roll(end + 1);
    assertFalse(maintenance.checkScheduled(consensus), "Should not be in maintenance after end");
  }

  function testConcrete_NonBlockProducer_CanSchedule() external {
    address[] memory blockProducerIds = validatorSet.getBlockProducerIds();
    address blockProducer = blockProducerIds[0];

    IProfile.CandidateProfile memory candidateProfile = profile.getId2Profile(blockProducer);
    address admin = candidateProfile.admin;
    TConsensus consensus = candidateProfile.consensus;

    // Jail the block producer
    address slashIndicator = IHasContracts(address(validatorSet)).getContract(ContractType.SLASH_INDICATOR);
    vm.prank(slashIndicator);
    validatorSet.execSlash(blockProducer, block.number + 1000, 0, false);

    _fastForwardToNextDay();
    _wrapUpEpoch();

    assertTrue(validatorSet.checkJailed(consensus), "Block producer should be jailed");
    assertFalse(validatorSet.isBlockProducer(consensus), "Jailed validator should not be a block producer");

    // Before maintenance
    assertFalse(maintenance.checkScheduled(consensus), "Should not be in maintenance before start");

    (,, uint256 start, uint256 end) = _schedule(blockProducer, 200);

    // During maintenance
    vm.roll(start + 1);
    assertTrue(maintenance.checkScheduled(consensus), "Should be in maintenance");

    // After maintenance
    vm.roll(end + 1);
    assertFalse(maintenance.checkScheduled(consensus), "Should not be in maintenance after end");
  }

  function testConcrete_TwoNonBlockProducers_And_OneBlockProducer_CanSchedule_WithDifferent_FutureTimeWindow() external {
    address[] memory validatorIds = validatorSet.getValidatorIds();

    // Jail two validators to make them non-block producers
    address slashIndicator = IHasContracts(address(validatorSet)).getContract(ContractType.SLASH_INDICATOR);
    vm.startPrank(slashIndicator);
    validatorSet.execSlash(validatorIds[0], block.number + 2000, 0, false);
    validatorSet.execSlash(validatorIds[1], block.number + 2000, 0, false);
    vm.stopPrank();

    _fastForwardToNextDay();
    _wrapUpEpoch();

    // Ensure 2 non-block producers and 1 block producer
    assertFalse(validatorSet.isBlockProducer(profile.getId2Profile(validatorIds[0]).consensus));
    assertFalse(validatorSet.isBlockProducer(profile.getId2Profile(validatorIds[1]).consensus));
    assertTrue(validatorSet.isBlockProducer(profile.getId2Profile(validatorIds[2]).consensus));

    uint256 blocksPE = validatorSet.numberOfBlocksInEpoch();

    // Schedule maintenance for Validator 1 (epoch N+2 -> N+3)
    TConsensus consensus = profile.getId2Profile(validatorIds[0]).consensus;
    vm.prank(profile.getId2Profile(validatorIds[0]).admin);
    maintenance.schedule(consensus, block.number + blocksPE + 1, block.number + blocksPE * 3);

    // Schedule maintenance for Validator 2 (epoch N+4 -> N+5)
    consensus = profile.getId2Profile(validatorIds[1]).consensus;
    vm.prank(profile.getId2Profile(validatorIds[1]).admin);
    maintenance.schedule(consensus, block.number + blocksPE * 3 + 1, block.number + blocksPE * 5);

    // Schedule maintenance for Validator 3 (epoch N+7 -> N+9)
    consensus = profile.getId2Profile(validatorIds[2]).consensus;
    vm.prank(profile.getId2Profile(validatorIds[2]).admin);
    maintenance.schedule(consensus, block.number + blocksPE * 6 + 1, block.number + blocksPE * 9);
    assertEq(maintenance.totalSchedule(), 3);

    // The request of the 4th validator get reverted if called at epoch N with whatever duration
    consensus = profile.getId2Profile(validatorIds[3]).consensus;
    vm.prank(profile.getId2Profile(validatorIds[3]).admin);
    vm.expectRevert(IMaintenance.ErrTotalOfSchedulesExceeded.selector);
    maintenance.schedule(consensus, block.number + blocksPE * 7 + 1, block.number + blocksPE * 9);

    // The request of the 4th validator is success if called at epoch N+4 within valid range duration (e.g. N+5 -> N+6)
    vm.roll(block.number + blocksPE * 3 + 1);
    consensus = profile.getId2Profile(validatorIds[3]).consensus;
    vm.prank(profile.getId2Profile(validatorIds[3]).admin);
    maintenance.schedule(consensus, block.number + blocksPE * 4, block.number + blocksPE * 6 - 1);
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
    // Calculate endBlock ensuring it's aligned with epoch boundaries
    uint256 maintenanceEpochs = (durationInBlock + numberOfBlocksInEpoch - 1) / numberOfBlocksInEpoch;
    endBlock = startBlock + maintenanceEpochs * numberOfBlocksInEpoch - 1;

    console.log("startBlock", startBlock);
    console.log("endBlock", endBlock);

    uint256 maintenanceElapsed = endBlock - startBlock + 1;
    require(maintenanceElapsed >= minDuration && maintenanceElapsed <= maxDuration, "Invalid maintenance duration");

    vm.prank(admin);
    maintenance.schedule(consensus, startBlock, endBlock);

    assertTrue(maintenance.checkScheduled(consensus));
    assertEq(maintenance.totalSchedule(), totalSchedule + 1);
  }

  function testFuzz_exitMaintenance(uint256 index) external {
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

  function _wrapUpEpochs(uint256 times) internal {
    for (uint256 i; i < times; ++i) {
      _fastForwardToNextDay();
      _wrapUpEpoch();
    }
  }

  function _wrapUpEpoch() internal {
    _wrapUpEpoch(block.coinbase);
  }

  function _wrapUpEpoch(address caller) internal {
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
