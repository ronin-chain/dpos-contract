// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { LibSharedAddress } from "@fdk/libraries/LibSharedAddress.sol";

import { Test, console } from "forge-std/Test.sol";
import { TransparentUpgradeableProxyV2 } from "src/extensions/TransparentUpgradeableProxyV2.sol";
import { IRoninValidatorSet } from "src/interfaces/validator/IRoninValidatorSet.sol";
import { IMaintenance, Maintenance } from "src/ronin/Maintenance.sol";
import { IProfile, Profile, TConsensus } from "src/ronin/profile/Profile.sol";
import { IStaking, Staking } from "src/ronin/staking/Staking.sol";

import { Test, console } from "forge-std/Test.sol";

import { DeployDPoS } from "script/deploy-dpos/DeployDPoS.s.sol";
import { ISharedArgument } from "script/interfaces/ISharedArgument.sol";
import { Contract } from "script/utils/Contract.sol";

import { LibPrecompile } from "script/shared/libraries/LibPrecompile.sol";
import { IHasContracts } from "src/interfaces/collections/IHasContracts.sol";
import { ISlashingExecution } from "src/interfaces/validator/ISlashingExecution.sol";
import { ContractType } from "src/utils/ContractType.sol";

contract Maintenance_Base_Test is Test {
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

  function _applyValidatorCandidate(
    address candidateAdmin,
    TConsensus consensusAddr,
    uint256 value
  ) internal {
    vm.deal(candidateAdmin, value);
    vm.startPrank(candidateAdmin);

    IStaking(address(staking)).applyValidatorCandidate{ value: value }(
      candidateAdmin,
      consensusAddr,
      payable(candidateAdmin),
      1500,
      bytes(string.concat("mock-pub-key", vm.toString(candidateAdmin))),
      bytes(string.concat("mock-proof-of-possession", vm.toString(candidateAdmin)))
    );

    vm.stopPrank();
  }

  function _schedule(
    address validatorId,
    uint256 durationInBlock
  ) internal returns (address admin, TConsensus consensus, uint256 startBlock, uint256 endBlock) {
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

    uint256 maintenanceElapsed = endBlock - startBlock + 1;
    require(maintenanceElapsed >= minDuration && maintenanceElapsed <= maxDuration, "Invalid maintenance duration");

    vm.prank(admin);
    maintenance.schedule(consensus, startBlock, endBlock);

    assertTrue(maintenance.checkScheduled(consensus));
    assertEq(maintenance.totalSchedule(), totalSchedule + 1);
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
