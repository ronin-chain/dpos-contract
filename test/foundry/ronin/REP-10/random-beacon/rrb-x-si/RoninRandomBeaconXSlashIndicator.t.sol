// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../REP-10_Base.t.sol";

contract RoninRandomBeaconXSlashIndicatorTest is REP10_BaseTest {
  function testConcrete_RecordUnavailability_IfGVNotSubmitBeacon_WhenWrapUpEpochAtTheEndOfPeriod() external {
    LibWrapUpEpoch.wrapUpPeriods({ times: 1, shouldSubmitBeacon: false });

    IRoninTrustedOrganization.TrustedOrganization[] memory gvs = roninTrustedOrganization.getAllTrustedOrganizations();
    address[] memory cids = new address[](gvs.length);

    for (uint256 i; i < gvs.length; ++i) {
      cids[i] = profile.getConsensus2Id(gvs[i].consensusAddr);
    }

    for (uint256 i; i < cids.length; ++i) {
      assertEq(roninRandomBeacon.getUnavailabilityCount(cids[i]), 1);
    }
  }

  function testConcrete_SlashRandomBeacon_IfNotSubmitBeacon_ExceedThreshold() external {
    LibVRFProof.VRFKey[] memory keys = abi.decode(vme.getUserDefinedConfig("vrf-keys"), (LibVRFProof.VRFKey[]));
    bytes32 keyHashToBeSlashed = keys[keys.length - 1].keyHash;
    uint256 keyCount = keys.length;
    address cidToBeSlash = profile.getVRFKeyHash2Id(keyHashToBeSlashed);

    // Remove the last key from the list
    assembly {
      mstore(keys, sub(keyCount, 1))
    }

    vme.setUserDefinedConfig("vrf-keys", abi.encode(keys));

    uint256 threshold = roninRandomBeacon.getUnavailabilitySlashThreshold();
    LibWrapUpEpoch.wrapUpPeriods({ times: threshold - 1, shouldSubmitBeacon: true });

    assertTrue(
      roninRandomBeacon.getUnavailabilityCount(cidToBeSlash) == threshold - 1,
      "Unavailability count should be threshold - 1"
    );
    for (uint256 i; i < keys.length; ++i) {
      assertTrue(
        roninRandomBeacon.getUnavailabilityCount(profile.getVRFKeyHash2Id(keys[i].keyHash)) == 0,
        "Unavailability count should be 0"
      );
    }

    uint256 currPeriod = _computePeriod(vm.getBlockTimestamp());
    vm.expectEmit(address(slashIndicator));
    emit IBaseSlash.Slashed(cidToBeSlash, IBaseSlash.SlashType.RANDOM_BEACON, currPeriod);

    LibWrapUpEpoch.wrapUpPeriods({ times: 1, shouldSubmitBeacon: true });

    assertTrue(roninRandomBeacon.getUnavailabilityCount(cidToBeSlash) == 0, "Unavailability count should be reset to 0");
  }
}
