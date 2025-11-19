// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { IProfile } from "src/interfaces/IProfile.sol";
import { TConsensus } from "src/udvts/Types.sol";

import { Maintenance_Base_Test } from "test/foundry/unit/ronin/maintenance/Maintenance.base.t.sol";

contract Maintenance_Fuzz_Test is Maintenance_Base_Test {
  function testFuzz_schedule(
    uint256 index,
    uint32 durationInBlock
  ) external {
    address[] memory validatorIds = validatorSet.getValidatorCandidateIds();
    address validatorId = validatorIds[index % validatorIds.length];

    _schedule(validatorId, durationInBlock);
  }

  function testFuzz_cancelSchedule(
    uint256 index
  ) external {
    address[] memory validatorIds = validatorSet.getValidatorCandidateIds();
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

    uint256 startBlock = latestEpochBlock + numberOfBlocksInEpoch + 1
      + ((minOffset + numberOfBlocksInEpoch) / numberOfBlocksInEpoch) * numberOfBlocksInEpoch;
    uint256 endBlock = startBlock - 1 + (durationInBlock / numberOfBlocksInEpoch + 1) * numberOfBlocksInEpoch;

    vm.prank(admin);
    maintenance.schedule(consensus, startBlock, endBlock);

    assertTrue(maintenance.checkScheduled(consensus));

    vm.prank(admin);
    maintenance.cancelSchedule(consensus);

    vm.roll(startBlock + 1);
    assertFalse(maintenance.checkScheduled(consensus), "maintenance is still scheduled");
    assertEq(maintenance.totalSchedule(), 0, "total schedule is not 0");
  }
}
