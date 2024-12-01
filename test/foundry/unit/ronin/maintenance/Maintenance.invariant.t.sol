// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { IMaintenance } from "src/interfaces/IMaintenance.sol";
import { TConsensus } from "src/udvts/Types.sol";

import { Maintenance_Base_Test } from "test/foundry/unit/ronin/maintenance/Maintenance.base.t.sol";

contract Maintenance_Invariant_Test is Maintenance_Base_Test {
  /// @notice Invariant: Total schedule must never exceed the maximum schedule.
  function invariant_totalSchedule_neverExceed_MaxSchedule() external view {
    assertTrue(maintenance.totalSchedule() <= maintenance.maxSchedule(), "total schedule exceeds max schedule");
  }

  /// @notice Invariant: All returned candidates have active schedules.
  function invariant_ActiveCandidatesOnly() external view {
    address[] memory activeCids = maintenance.getActiveSchedules();
    bool[] memory areScheduled = maintenance.checkManyMaintainedById(activeCids, block.number);

    for (uint256 i = 0; i < activeCids.length; ++i) {
      assertTrue(areScheduled[i], "Candidate is not maintained");
    }
  }

  /// @notice Invariant: No maintenance should be scheduled without a valid duration.
  function invariant_EpochValidation() external view {
    TConsensus[] memory consensuses = validatorSet.getValidatorCandidates();
    for (uint256 i; i < consensuses.length; ++i) {
      TConsensus consensusAddr = consensuses[i];
      IMaintenance.Schedule memory schedule = maintenance.getSchedule(consensusAddr);

      if (schedule.from != 0 && schedule.to != 0) {
        bool startIsEpochEnd = validatorSet.epochEndingAt(schedule.from - 1);
        bool endIsEpochEnd = validatorSet.epochEndingAt(schedule.to);

        assertTrue(startIsEpochEnd, "Start block is not the end of an epoch");
        assertTrue(endIsEpochEnd, "End block is not the end of an epoch");
      }
    }
  }

  /// @notice Invariant: No maintenance should be scheduled without a valid duration.
  function invariant_NoMaintenanceWithoutSchedule() external view {
    TConsensus[] memory consensuses = validatorSet.getValidatorCandidates();

    for (uint256 i; i < consensuses.length; ++i) {
      TConsensus consensusAddr = consensuses[i];
      bool isMaintained = maintenance.checkMaintained(consensusAddr, block.number);
      IMaintenance.Schedule memory schedule = maintenance.getSchedule(consensusAddr);

      if (!isMaintained) {
        assertEq(schedule.from, 0, "Candidate is maintained without a valid schedule");
      }
    }
  }

  /// @notice Invariant: Maintenance durations must always remain within defined bounds.
  function invariant_MaintenanceDurationsValid() external view {
    TConsensus[] memory consensuses = validatorSet.getValidatorCandidates();
    for (uint256 i; i < consensuses.length; ++i) {
      TConsensus consensusAddr = consensuses[i];
      IMaintenance.Schedule memory schedule = maintenance.getSchedule(consensusAddr);

      if (schedule.from != 0 && schedule.to != 0) {
        uint256 duration = schedule.to - schedule.from + 1;
        uint256 minDuration = maintenance.minMaintenanceDurationInBlock();
        uint256 maxDuration = maintenance.maxMaintenanceDurationInBlock();

        assertGe(duration, minDuration, "Maintenance duration is below the minimum limit");
        assertLe(duration, maxDuration, "Maintenance duration exceeds the maximum limit");
      }
    }
  }

  /// @notice Invariant: No schedules should be active for candidates outside of their maintenance window.
  function invariant_NoActiveOutsideWindow() external view {
    uint256 currentBlock = block.number;

    address[] memory cids = validatorSet.getValidatorCandidateIds();
    for (uint256 i; i < cids.length; ++i) {
      address candidateId = cids[i];
      TConsensus consensusAddr = profile.getId2Consensus(candidateId);

      bool isMaintained = maintenance.checkMaintainedById(candidateId, currentBlock);
      IMaintenance.Schedule memory schedule = maintenance.getSchedule(consensusAddr);

      if (isMaintained) {
        assertGe(currentBlock, schedule.from, "Current block is before the maintenance window");
        assertLe(currentBlock, schedule.to, "Current block is after the maintenance window");
      }
    }
  }

  /// @notice Invariant: The cooldown period must be respected before scheduling again.
  function invariant_CooldownEnforced() external view {
    TConsensus[] memory consensuses = validatorSet.getValidatorCandidates();
    for (uint256 i; i < consensuses.length; ++i) {
      TConsensus consensusAddr = consensuses[i];
      bool cooldownEnded = maintenance.checkCooldownEnded(consensusAddr);
      IMaintenance.Schedule memory schedule = maintenance.getSchedule(consensusAddr);

      if (schedule.requestTimestamp != 0) {
        uint256 cooldownSecs = maintenance.cooldownSecsToMaintain();
        uint256 elapsedTime = block.timestamp - schedule.requestTimestamp;

        if (!cooldownEnded) {
          assertLt(elapsedTime, cooldownSecs, "Cooldown period has not been respected");
        } else {
          assertGe(elapsedTime, cooldownSecs, "Cooldown should have ended");
        }
      }
    }
  }
}
