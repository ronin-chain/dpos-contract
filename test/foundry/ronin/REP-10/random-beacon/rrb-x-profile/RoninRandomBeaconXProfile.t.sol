// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../REP-10_Base.t.sol";

contract RoninRandomBeaconXProfileTest is REP10_BaseTest {
  function testFail_ChangeSameKeyAsOtherAdmin() external {
    LibVRFProof.VRFKey[] memory keys = abi.decode(vme.getUserDefinedConfig("vrf-keys"), (LibVRFProof.VRFKey[]));
    LibVRFProof.VRFKey memory keyToChange = keys[keys.length - 1];

    address cidToChangeVRF = profile.getVRFKeyHash2Id(keyToChange.keyHash);
    address adminToChangeVRF = profile.getId2Admin(cidToChangeVRF);

    vm.prank(adminToChangeVRF);
    profile.changeVRFKeyHash(cidToChangeVRF, keys[0].keyHash);

    LibWrapUpEpoch.wrapUpPeriod();
  }

  function testConcrete_NewlyChangedVRFKey_CanSubmitRandom_ForNextPeriod() external {
    LibVRFProof.VRFKey[] memory keys = abi.decode(vme.getUserDefinedConfig("vrf-keys"), (LibVRFProof.VRFKey[]));
    LibVRFProof.VRFKey memory keyToChange = keys[keys.length - 1];
    address cidToChangeVRF = profile.getVRFKeyHash2Id(keyToChange.keyHash);
    address adminToChangeVRF = profile.getId2Admin(cidToChangeVRF);
    LibVRFProof.VRFKey memory newKey = LibVRFProof.genVRFKeys(1)[0];

    keys[keys.length - 1] = newKey;

    vme.setUserDefinedConfig("vrf-keys", abi.encode(keys));

    vm.prank(adminToChangeVRF);
    profile.changeVRFKeyHash(cidToChangeVRF, newKey.keyHash);

    LibWrapUpEpoch.wrapUpPeriod();
  }

  function testFailConcrete_RevertWhen_NewlyChangedVRFKey_SubmitForBeacon() external {
    LibWrapUpEpoch.wrapUpPeriods({ times: 1, shouldSubmitBeacon: false });

    LibVRFProof.VRFKey[] memory keys = abi.decode(vme.getUserDefinedConfig("vrf-keys"), (LibVRFProof.VRFKey[]));
    LibVRFProof.VRFKey memory keyToRemove = keys[keys.length - 1];

    console.log("Key to remove", vm.toString(keyToRemove.keyHash));

    address cidToChangeVRF = profile.getVRFKeyHash2Id(keyToRemove.keyHash);
    address adminToChangeVRF = profile.getId2Admin(cidToChangeVRF);
    LibVRFProof.VRFKey memory newKey = LibVRFProof.genVRFKeys(1)[0];

    console.log("New key", vm.toString(newKey.keyHash));

    keys[keys.length - 1] = newKey;
    vm.label(newKey.oracle, "new-oracle");

    vme.setUserDefinedConfig("vrf-keys", abi.encode(keys));

    vm.prank(adminToChangeVRF);
    profile.changeVRFKeyHash(cidToChangeVRF, newKey.keyHash);

    LibWrapUpEpoch.wrapUpEpochAndSubmitBeacons(keys);
  }

  function testConcrete_WhenPassedRegisteredCoolDown_NewlyJoinedGoverningValidator_canSubmitBeacon() external {
    LibWrapUpEpoch.wrapUpPeriods({ times: 1, shouldSubmitBeacon: false });
    LibWrapUpEpoch.wrapUpEpoch();

    address newCandidate = makeAddr("new-candidate");
    address newConsensus = makeAddr("new-consensus");
    LibApplyCandidate.applyValidatorCandidate(address(staking), newCandidate, newConsensus);

    IRoninTrustedOrganization.TrustedOrganization memory gov = IRoninTrustedOrganization.TrustedOrganization({
      governor: makeAddr("new-governor"),
      __deprecatedBridgeVoter: address(0x0),
      addedBlock: 0,
      consensusAddr: TConsensus.wrap(newConsensus),
      weight: 200
    });

    IRoninTrustedOrganization.TrustedOrganization[] memory gvs = new IRoninTrustedOrganization.TrustedOrganization[](1);
    gvs[0] = gov;
    vm.prank(address(governanceAdmin));
    TransparentUpgradeableProxyV2(payable(address(roninTrustedOrganization))).functionDelegateCall(
      abi.encodeCall(IRoninTrustedOrganization.addTrustedOrganizations, (gvs))
    );

    LibVRFProof.VRFKey[] memory keys = abi.decode(vme.getUserDefinedConfig("vrf-keys"), (LibVRFProof.VRFKey[]));
    LibVRFProof.VRFKey[] memory newKeys = new LibVRFProof.VRFKey[](keys.length + 1);

    // Copy the existing keys
    for (uint256 i; i < keys.length; ++i) {
      newKeys[i] = keys[i];
    }

    // Gen a new key
    LibVRFProof.VRFKey memory newKey = LibVRFProof.genVRFKeys(1)[0];
    newKeys[keys.length] = newKey;
    vm.label(newKey.oracle, "new-oracle");

    vme.setUserDefinedConfig("vrf-keys", abi.encode(newKeys));

    address cid = profile.getConsensus2Id(TConsensus.wrap(newConsensus));
    // Update key hash for new GV
    vm.prank(profile.getId2Admin(cid));
    profile.changeVRFKeyHash(cid, newKey.keyHash);

    LibWrapUpEpoch.wrapUpPeriods({ times: 1, shouldSubmitBeacon: true });
  }
}
