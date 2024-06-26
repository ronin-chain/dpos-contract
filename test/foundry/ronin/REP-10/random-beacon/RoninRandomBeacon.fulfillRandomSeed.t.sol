// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../REP-10_Base.t.sol";

contract RoninRandomBeacon_FulfillRandomSeed_Test is REP10_BaseTest {
  function testFuzz_FilterOutNewlyJoinedGoverningValidator_execWrapUpBeaconPeriod(uint256 wrapUpEpochCount) external {
    address newCandidate = makeAddr("new-candidate");
    address newConsensus = makeAddr("new-consensus");
    address newGovernor = makeAddr("new-governor");
    LibApplyCandidate.applyValidatorCandidate(address(staking), newCandidate, newConsensus);

    IRoninTrustedOrganization.TrustedOrganization memory gov = IRoninTrustedOrganization.TrustedOrganization({
      governor: newGovernor,
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

    LibWrapUpEpoch.wrapUpPeriods({ times: 1, shouldSubmitBeacon: false });
    wrapUpEpochCount = bound(wrapUpEpochCount, 1, 10);

    for (uint256 i; i < wrapUpEpochCount; ++i) {
      LibWrapUpEpoch.wrapUpEpoch();

      address[] memory validatorIds = roninValidatorSet.getValidatorIds();
      bool contains;

      for (uint256 j; j < validatorIds.length; ++j) {
        if (validatorIds[j] == profile.getConsensus2Id(TConsensus.wrap(newConsensus))) {
          contains = true;
          break;
        }
      }

      assertFalse(contains, "Newly joined GV should not be included in the validator set");
    }
  }

  function testFuzz_FilterOutNewlyJoinedStandardValidator_execWrapUpBeaconPeriod(uint256 wrapUpEpochCount) external {
    address newCandidate = makeAddr("new-candidate");
    address newConsensus = makeAddr("new-consensus");
    LibApplyCandidate.applyValidatorCandidate(address(staking), newCandidate, newConsensus);

    LibWrapUpEpoch.wrapUpPeriods({ times: 1, shouldSubmitBeacon: false });
    wrapUpEpochCount = bound(wrapUpEpochCount, 1, 10);

    for (uint256 i; i < wrapUpEpochCount; ++i) {
      LibWrapUpEpoch.wrapUpEpoch();

      address[] memory validatorIds = roninValidatorSet.getValidatorIds();
      bool contains;

      for (uint256 j; j < validatorIds.length; ++j) {
        if (validatorIds[j] == profile.getConsensus2Id(TConsensus.wrap(newConsensus))) {
          contains = true;
          break;
        }
      }

      assertFalse(contains, "Newly joined standard validator should not be included in the validator set");
    }
  }

  function testFail_IfResubmitBeacon() external {
    LibVRFProof.VRFKey[] memory keys = abi.decode(vme.getUserDefinedConfig("vrf-keys"), (LibVRFProof.VRFKey[]));
    // Duplicate the last key
    keys[0] = keys[keys.length - 1];

    vme.setUserDefinedConfig("vrf-keys", abi.encode(keys));

    LibWrapUpEpoch.wrapUpPeriods({ times: 1, shouldSubmitBeacon: true });
  }

  function testFail_VRFKeyHashOwner_IsNotGoverningValidator() external {
    LibVRFProof.VRFKey[] memory keys = abi.decode(vme.getUserDefinedConfig("vrf-keys"), (LibVRFProof.VRFKey[]));
    LibVRFProof.VRFKey[] memory newKeys = new LibVRFProof.VRFKey[](keys.length + 1);

    // Copy the existing keys
    for (uint256 i; i < keys.length; ++i) {
      newKeys[i] = keys[i];
    }

    // Gen a new invalid key
    LibVRFProof.VRFKey memory invalidKey = LibVRFProof.genVRFKeys(1)[0];
    newKeys[keys.length] = invalidKey;

    address[] memory allCids = roninValidatorSet.getValidatorCandidateIds();
    address standardValidatorId;
    for (uint256 i; i < allCids.length; ++i) {
      if (roninTrustedOrganization.getConsensusWeightById(allCids[i]) == 0) {
        standardValidatorId = allCids[i];
        break;
      }
    }

    vme.setUserDefinedConfig("vrf-keys", abi.encode(newKeys));

    address adminToChangeVRF = profile.getId2Admin(standardValidatorId);
    vm.prank(adminToChangeVRF);
    profile.changeVRFKeyHash(standardValidatorId, invalidKey.keyHash);

    LibWrapUpEpoch.wrapUpPeriods({ times: 1, shouldSubmitBeacon: true });
  }

  function testFailConcrete_RevertIf_NewlyJoinedGoverningValidator_SubmitBeacon() external {
    LibWrapUpEpoch.wrapUpPeriods({ times: 1, shouldSubmitBeacon: false });

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

    vme.setUserDefinedConfig("vrf-keys", abi.encode(newKeys));

    address cid = profile.getConsensus2Id(TConsensus.wrap(newConsensus));
    // Update key hash for new GV
    vm.prank(profile.getId2Admin(cid));
    profile.changeVRFKeyHash(cid, newKey.keyHash);

    LibWrapUpEpoch.wrapUpEpochAndSubmitBeacons(newKeys);
  }
}
