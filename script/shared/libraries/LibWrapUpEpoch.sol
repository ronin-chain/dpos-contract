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

  function wrapUpPeriods(uint256 times, bool shouldSubmitBeacon) internal {
    LibVRFProof.VRFKey[] memory keys = abi.decode(config.getUserDefinedConfig("vrf-keys"), (LibVRFProof.VRFKey[]));

    for (uint256 i; i < times; ++i) {
      fastForwardToNextDay();
      wrapUpEpoch();

      if (!shouldSubmitBeacon) continue;

      fastForwardToNextEpoch();
      wrapUpEpochAndSubmitBeacons(keys);
    }
  }

  function wrapUpPeriods(uint256 times) internal {
    wrapUpPeriods(times, true);
  }

  function wrapUpPeriod() internal {
    wrapUpPeriods(1);
  }

  function wrapUpEpochs(uint256 times) internal {
    LibVRFProof.VRFKey[] memory keys = abi.decode(config.getUserDefinedConfig("vrf-keys"), (LibVRFProof.VRFKey[]));

    for (uint256 i; i < times; ++i) {
      fastForwardToNextEpoch();
      wrapUpEpochAndSubmitBeacons(keys);
    }
  }

  function wrapUpEpoch() internal {
    fastForwardToNextEpoch();
    wrapUpEpoch(block.coinbase);
  }

  function wrapUpEpochAndSubmitBeacons(LibVRFProof.VRFKey[] memory keys) internal {
    fastForwardToNextEpoch();
    wrapUpEpochAndSubmitBeacons(keys, block.coinbase);
  }

  function wrapUpEpoch(address caller) private {
    vm.startPrank(caller);
    IRoninValidatorSet(config.getAddressFromCurrentNetwork(Contract.RoninValidatorSet.key())).wrapUpEpoch();
    vm.stopPrank();
  }

  function wrapUpEpochAndSubmitBeacons(LibVRFProof.VRFKey[] memory keys, address caller) private {
    vm.recordLogs();
    wrapUpEpoch(caller);
    LibVRFProof.listenEventAndSubmitProof(keys);
  }

  function fastForwardToNextEpoch() internal {
    vm.roll(vm.getBlockNumber() + 1);
    vm.warp(vm.getBlockTimestamp() + 1);

    IRoninValidatorSet validatorSet =
      IRoninValidatorSet(config.getAddressFromCurrentNetwork(Contract.RoninValidatorSet.key()));

    uint256 diff;
    uint256 startBlock = validatorSet.currentPeriodStartAtBlock();

    if (startBlock > vm.getBlockNumber()) {
      diff = startBlock - vm.getBlockNumber();
      vm.roll(startBlock);
      vm.warp(vm.getBlockTimestamp() + 1);
    }

    uint256 startEpoch = validatorSet.epochOf(startBlock);
    uint256 numberOfBlocksInEpoch = validatorSet.numberOfBlocksInEpoch();
    uint256 currEpoch = validatorSet.epochOf(vm.getBlockNumber());

    uint256 startBlockOfCurrentEpoch = startBlock + (currEpoch - startEpoch) * numberOfBlocksInEpoch;
    diff = vm.getBlockNumber() - startBlockOfCurrentEpoch;
    uint256 startTimestampOfCurrentEpoch = vm.getBlockTimestamp() +1 ;

    uint256 nextEpochBlockNumber =
      startBlockOfCurrentEpoch + (numberOfBlocksInEpoch - 1) - (startBlockOfCurrentEpoch % numberOfBlocksInEpoch);
    uint256 nextEpochTimestamp = startTimestampOfCurrentEpoch + 1;

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
