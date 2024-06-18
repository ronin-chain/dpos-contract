// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../REP-10_Base.t.sol";

contract RoninRandomBeacon_ExecWrapUpBeaconPeriod_Test is REP10_BaseTest {
  function testConcrete_EmitBeaconFinalizedEvent_WhenWrapUpAtTheEndOfPeriod() external {
    uint256 currPeriod = _computePeriod(vm.getBlockTimestamp());
    (uint256 beaconValue,) = roninRandomBeacon.getBeacon(currPeriod);

    vm.expectEmit(address(roninRandomBeacon));
    emit IRandomBeacon.BeaconFinalized(currPeriod + 1, beaconValue);

    LibWrapUpEpoch.wrapUpPeriods({ times: 1, shouldSubmitBeacon: false });
  }
}
