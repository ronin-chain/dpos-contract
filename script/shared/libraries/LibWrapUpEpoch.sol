// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Vm, VmSafe } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";
import { Contract } from "script/utils/Contract.sol";
import { IGeneralConfig } from "@fdk/interfaces/IGeneralConfig.sol";
import { LibSharedAddress } from "@fdk/libraries/LibSharedAddress.sol";
import { IRoninValidatorSet } from "@ronin/contracts/interfaces/validator/IRoninValidatorSet.sol";
import { VRF, LibVRFProof } from "./LibVRFProof.sol";

library LibWrapUpEpoch {
  Vm internal constant vm = Vm(LibSharedAddress.VM);
  IGeneralConfig internal constant config = IGeneralConfig(LibSharedAddress.VME);

  function wrapUpPeriod() internal {
    wrapUpPeriods({ times: 1 });
  }

  function wrapUpPeriods(uint256 times) internal {
    wrapUpPeriods({ times: times, shouldSubmitBeacon: false });
  }

  function wrapUpPeriods(uint256 times, bool shouldSubmitBeacon) internal {
    LibVRFProof.VRFKey[] memory keys;
    bytes memory raw = config.getUserDefinedConfig("vrf-keys");

    if (raw.length != 0) {
      keys = abi.decode(raw, (LibVRFProof.VRFKey[]));
    } else {
      require(!shouldSubmitBeacon, "LibWrapUpEpoch: no VRF keys");
    }

    for (uint256 i; i < times; ++i) {
      fastForwardToNextDay();
      _wrapUpEpoch();

      if (!shouldSubmitBeacon) continue;

      wrapUpEpochAndSubmitBeacons(keys);
    }
  }

  function wrapUpEpochs(uint256 times, bool shouldSubmitBeacon) internal {
    LibVRFProof.VRFKey[] memory keys;
    bytes memory raw = config.getUserDefinedConfig("vrf-keys");
    
    if (raw.length != 0) {
      keys = abi.decode(raw, (LibVRFProof.VRFKey[]));
    } else {
      require(!shouldSubmitBeacon, "LibWrapUpEpoch: no VRF keys");
    }

    for (uint256 i; i < times; ++i) {
      if (shouldSubmitBeacon) {
        wrapUpEpochAndSubmitBeacons(keys);
      } else {
        wrapUpEpoch();
      }
    }
  }

  function wrapUpEpoch() internal {
    fastForwardToNextEpoch();
    _wrapUpEpoch();
  }

  function wrapUpEpochAndSubmitBeacons(LibVRFProof.VRFKey[] memory keys) internal {
    fastForwardToNextEpoch();
    _wrapUpEpochAndSubmitBeacons(keys);
  }

  function _wrapUpEpoch() private {
    IRoninValidatorSet validatorSet =
      IRoninValidatorSet(config.getAddressFromCurrentNetwork(Contract.RoninValidatorSet.key()));
    vm.startPrank(block.coinbase);
    validatorSet.wrapUpEpoch();
    vm.stopPrank();

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

  function _wrapUpEpochAndSubmitBeacons(LibVRFProof.VRFKey[] memory keys) private {
    vm.recordLogs();
    _wrapUpEpoch();
    LibVRFProof.listenEventAndSubmitProof(keys);
  }

  function fastForwardToNextEpoch() internal {
    vm.roll(vm.getBlockNumber() + 1);
    vm.warp(vm.getBlockTimestamp() + 3);

    IRoninValidatorSet validatorSet =
      IRoninValidatorSet(config.getAddressFromCurrentNetwork(Contract.RoninValidatorSet.key()));

    uint256 diff;
    uint256 startBlock = validatorSet.currentPeriodStartAtBlock();

    if (startBlock > vm.getBlockNumber()) {
      diff = startBlock - vm.getBlockNumber();
      vm.roll(startBlock);
      vm.warp(vm.getBlockTimestamp() + diff * 3);
    }

    uint256 startEpoch = validatorSet.epochOf(startBlock);
    uint256 numberOfBlocksInEpoch = validatorSet.numberOfBlocksInEpoch();
    uint256 currEpoch = validatorSet.epochOf(vm.getBlockNumber());

    uint256 startBlockOfCurrentEpoch = startBlock + (currEpoch - startEpoch) * numberOfBlocksInEpoch;
    diff = vm.getBlockNumber() - startBlockOfCurrentEpoch;
    uint256 startTimestampOfCurrentEpoch = vm.getBlockTimestamp() - diff * 3;

    uint256 nextEpochBlockNumber =
      startBlockOfCurrentEpoch + (numberOfBlocksInEpoch - 1) - (startBlockOfCurrentEpoch % numberOfBlocksInEpoch);
    uint256 nextEpochTimestamp = startTimestampOfCurrentEpoch + numberOfBlocksInEpoch * 3;

    vm.roll(nextEpochBlockNumber);
    vm.warp(nextEpochTimestamp);
  }

  function fastForwardToNextDay() internal {
    vm.roll(vm.getBlockNumber() + 1);
    vm.warp(vm.getBlockTimestamp() + 3);

    IRoninValidatorSet validatorSet =
      IRoninValidatorSet(config.getAddressFromCurrentNetwork(Contract.RoninValidatorSet.key()));

    uint256 diff;
    uint256 startBlock = validatorSet.currentPeriodStartAtBlock();

    if (startBlock > vm.getBlockNumber()) {
      diff = startBlock - vm.getBlockNumber();
      vm.roll(startBlock);
      vm.warp(vm.getBlockTimestamp() + diff * 3);
    }

    uint256 numberOfBlocksInEpoch = validatorSet.numberOfBlocksInEpoch();

    diff = vm.getBlockNumber() - startBlock;
    uint256 startTimestampOfCurrentPeriod = vm.getBlockTimestamp() - diff * 3;

    uint256 nextDayTimestamp = startTimestampOfCurrentPeriod + 1 days;
    uint256 multiplier = (nextDayTimestamp - startTimestampOfCurrentPeriod) / (3 * numberOfBlocksInEpoch) - 1;

    uint256 nextDayEpochBlockNumber = startBlock + (multiplier * numberOfBlocksInEpoch);

    uint256 endOfDayEpochBlockNumber =
      nextDayEpochBlockNumber + (numberOfBlocksInEpoch - 1) - (startBlock % numberOfBlocksInEpoch);

    vm.warp(nextDayTimestamp);
    vm.roll(endOfDayEpochBlockNumber);
  }
}
