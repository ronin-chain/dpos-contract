// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../REP-10_Base.t.sol";

contract RoninRandomBeacon_ExecRequestRandomSeedForNextPeriod_Test is REP10_BaseTest {
  function testConcrete_EmitRandomSeedRequested_WhenWrapUpAtTheStartOfPeriod() external {
    LibWrapUpEpoch.wrapUpPeriods({ times: 1, shouldSubmitBeacon: false });

    uint256 currPeriod = _computePeriod(vm.getBlockTimestamp());
    (uint256 prevBeacon,) = roninRandomBeacon.getBeacon(currPeriod);
    RandomRequest memory req = RandomRequest({ period: currPeriod + 1, prevBeacon: prevBeacon });

    vm.expectEmit(address(roninRandomBeacon));
    emit IRandomBeacon.RandomSeedRequested(currPeriod + 1, req.hash(), req);

    LibWrapUpEpoch.wrapUpEpoch();
  }
}
