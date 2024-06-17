// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Vm, VmSafe } from "forge-std/Vm.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { console } from "forge-std/console.sol";
import { Contract } from "script/utils/Contract.sol";
import { IGeneralConfig } from "@fdk/interfaces/IGeneralConfig.sol";
import { LibSharedAddress } from "@fdk/libraries/LibSharedAddress.sol";
import { ICoinbaseExecution } from "@ronin/contracts/interfaces/validator/ICoinbaseExecution.sol";
import { IRoninValidatorSet } from "@ronin/contracts/interfaces/validator/IRoninValidatorSet.sol";
import { VRF, LibVRFProof } from "./LibVRFProof.sol";

library LibWrapUpEpoch {
  using StdStyle for *;

  Vm internal constant vm = Vm(LibSharedAddress.VM);
  IGeneralConfig internal constant vme = IGeneralConfig(LibSharedAddress.VME);

  function wrapUpPeriod() internal returns (VmSafe.Log[] memory logs) {
    logs = wrapUpPeriods({ times: 1 })[0];
  }

  function wrapUpPeriods(uint256 times) internal returns (VmSafe.Log[][] memory logs) {
    logs = wrapUpPeriods({ times: times, shouldSubmitBeacon: false });
  }

  function wrapUpPeriods(uint256 times, bool shouldSubmitBeacon) internal returns (VmSafe.Log[][] memory logs) {
    LibVRFProof.VRFKey[] memory keys;
    bytes memory raw = vme.getUserDefinedConfig("vrf-keys");

    if (raw.length != 0) {
      keys = abi.decode(raw, (LibVRFProof.VRFKey[]));
    } else {
      require(!shouldSubmitBeacon, "LibWrapUpEpoch: no VRF keys");
    }

    uint256 logLength = shouldSubmitBeacon ? times * 2 : times;
    logs = new VmSafe.Log[][](logLength);
    uint256 index;
    for (uint256 i; i < times; ++i) {
      fastForwardToNextDay();
      logs[index++] = _wrapUpEpoch();

      if (!shouldSubmitBeacon) continue;

      logs[index++] = wrapUpEpochAndSubmitBeacons(keys);
    }
  }

  function wrapUpEpochs(uint256 times, bool shouldSubmitBeacon) internal returns (VmSafe.Log[][] memory logs) {
    LibVRFProof.VRFKey[] memory keys;
    bytes memory raw = vme.getUserDefinedConfig("vrf-keys");

    if (raw.length != 0) {
      keys = abi.decode(raw, (LibVRFProof.VRFKey[]));
    } else {
      require(!shouldSubmitBeacon, "LibWrapUpEpoch: no VRF keys");
    }

    logs = new VmSafe.Log[][](times);
    for (uint256 i; i < times; ++i) {
      if (shouldSubmitBeacon) {
        logs[i] = wrapUpEpochAndSubmitBeacons(keys);
      } else {
        logs[i] = wrapUpEpoch();
      }
    }
  }

  function wrapUpEpoch() internal returns (VmSafe.Log[] memory logs) {
    fastForwardToNextEpoch();
    logs = _wrapUpEpoch();
  }

  function wrapUpEpochAndSubmitBeacons(LibVRFProof.VRFKey[] memory keys) internal returns (VmSafe.Log[] memory logs) {
    fastForwardToNextEpoch();
    logs = _wrapUpEpochAndSubmitBeacons(keys);
  }

  function _wrapUpEpoch() private returns (VmSafe.Log[] memory logs) {
    IRoninValidatorSet validatorSet =
      IRoninValidatorSet(vme.getAddressFromCurrentNetwork(Contract.RoninValidatorSet.key()));
    vm.recordLogs();

    vm.startPrank(block.coinbase);
    validatorSet.wrapUpEpoch();
    vm.stopPrank();

    logs = vm.getRecordedLogs();
    for (uint256 i; i < logs.length; ++i) {
      if (
        logs[i].emitter == address(validatorSet) && logs[i].topics[0] == ICoinbaseExecution.EmptyValidatorSet.selector
      ) {
        console.log("LibWrapUpEpoch: WARNING: EMPTY VALIDATOR SET".yellow());
      }
    }

    uint256 blockProducerCount = validatorSet.getBlockProducers().length;
    uint256 validatorCount = validatorSet.getValidators().length;
    uint256 validatorCandidateCount = validatorSet.getValidatorCandidates().length;

    require(blockProducerCount > 0, "LibWrapUpEpoch: no block producer");
    require(validatorCount > 0, "LibWrapUpEpoch: no validator");
    require(validatorCandidateCount > 0, "LibWrapUpEpoch: no validator candidate");
    require(
      blockProducerCount == validatorSet.getBlockProducerIds().length, "LibWrapUpEpoch: invalid block producer set"
    );
    require(validatorCount == validatorSet.getValidatorIds().length, "LibWrapUpEpoch: invalid validator set");
    require(
      validatorCandidateCount == validatorSet.getValidatorCandidateIds().length,
      "LibWrapUpEpoch: invalid validator candidate set"
    );
  }

  function _wrapUpEpochAndSubmitBeacons(LibVRFProof.VRFKey[] memory keys) private returns (VmSafe.Log[] memory logs) {
    logs = _wrapUpEpoch();
    LibVRFProof.listenEventAndSubmitProof(keys, logs);
  }

  function fastForwardToNextEpoch() internal {
    uint256 blockTime = vme.getNetworkData(vme.getCurrentNetwork()).blockTime;
    vm.roll(vm.getBlockNumber() + 1);
    vm.warp(vm.getBlockTimestamp() + blockTime);

    IRoninValidatorSet validatorSet =
      IRoninValidatorSet(vme.getAddressFromCurrentNetwork(Contract.RoninValidatorSet.key()));

    uint256 diff;
    uint256 startBlock = validatorSet.currentPeriodStartAtBlock();

    if (startBlock > vm.getBlockNumber()) {
      diff = startBlock - vm.getBlockNumber();
      vm.roll(startBlock);
      vm.warp(vm.getBlockTimestamp() + diff * blockTime);
    }

    uint256 startEpoch = validatorSet.epochOf(startBlock);
    uint256 numberOfBlocksInEpoch = validatorSet.numberOfBlocksInEpoch();
    uint256 currEpoch = validatorSet.epochOf(vm.getBlockNumber());

    uint256 startBlockOfCurrentEpoch = startBlock + (currEpoch - startEpoch) * numberOfBlocksInEpoch;
    diff = vm.getBlockNumber() - startBlockOfCurrentEpoch;
    uint256 startTimestampOfCurrentEpoch = vm.getBlockTimestamp() - diff * blockTime;

    uint256 nextEpochBlockNumber =
      startBlockOfCurrentEpoch + (numberOfBlocksInEpoch - 1) - (startBlockOfCurrentEpoch % numberOfBlocksInEpoch);
    uint256 nextEpochTimestamp = startTimestampOfCurrentEpoch + numberOfBlocksInEpoch * blockTime;

    vm.roll(nextEpochBlockNumber);
    vm.warp(nextEpochTimestamp);
  }

  function fastForwardToNextDay() internal {
    uint256 blockTime = vme.getNetworkData(vme.getCurrentNetwork()).blockTime;
    vm.roll(vm.getBlockNumber() + 1);
    vm.warp(vm.getBlockTimestamp() + blockTime);

    IRoninValidatorSet validatorSet =
      IRoninValidatorSet(vme.getAddressFromCurrentNetwork(Contract.RoninValidatorSet.key()));

    uint256 diff;
    uint256 startBlock = validatorSet.currentPeriodStartAtBlock();

    if (startBlock > vm.getBlockNumber()) {
      diff = startBlock - vm.getBlockNumber();
      vm.roll(startBlock);
      vm.warp(vm.getBlockTimestamp() + diff * blockTime);
    }

    uint256 numberOfBlocksInEpoch = validatorSet.numberOfBlocksInEpoch();

    diff = vm.getBlockNumber() - startBlock;
    uint256 startTimestampOfCurrentPeriod = vm.getBlockTimestamp() - diff * blockTime;

    uint256 nextDayTimestamp = startTimestampOfCurrentPeriod + 1 days;
    uint256 multiplier = (nextDayTimestamp - startTimestampOfCurrentPeriod) / (blockTime * numberOfBlocksInEpoch) - 1;

    uint256 nextDayEpochBlockNumber = startBlock + (multiplier * numberOfBlocksInEpoch);

    uint256 endOfDayEpochBlockNumber =
      nextDayEpochBlockNumber + (numberOfBlocksInEpoch - 1) - (startBlock % numberOfBlocksInEpoch);

    vm.warp(nextDayTimestamp);
    vm.roll(endOfDayEpochBlockNumber);
  }
}
