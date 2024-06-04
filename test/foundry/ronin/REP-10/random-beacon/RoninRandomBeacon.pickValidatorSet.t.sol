// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../REP-10_Base.t.sol";

contract RoninRandomBacon_PickValidatorSet_Test is REP10_BaseTest {
  function testFuzz_AlwaysContainsGV_getValidatorIds(uint256 wrapUpEpochCount, uint256 wrapUpPeriodCount) external {
    wrapUpEpochCount = bound(wrapUpEpochCount, 1, 10);
    wrapUpPeriodCount = bound(wrapUpPeriodCount, 1, 5);

    IRoninTrustedOrganization.TrustedOrganization[] memory gvs = roninTrustedOrganization.getAllTrustedOrganizations();
    address[] memory cids = new address[](gvs.length);

    for (uint256 i; i < gvs.length; ++i) {
      cids[i] = profile.getConsensus2Id(gvs[i].consensusAddr);
    }

    for (uint256 i; i < wrapUpPeriodCount; ++i) {
      LibWrapUpEpoch.wrapUpPeriods({ times: 1, shouldSubmitBeacon: false });

      for (uint256 j; j < wrapUpEpochCount; ++j) {
        address[] memory validatorIds = roninValidatorSet.getValidatorIds();

        bool contains;

        for (uint256 m; m < cids.length; ++m) {
          contains = false;
          for (uint256 k; k < validatorIds.length; ++k) {
            if (cids[m] == validatorIds[k]) {
              contains = true;
              break;
            }
          }
          assertTrue(contains, "Validator IDs should contain GV");
        }

        LibWrapUpEpoch.wrapUpEpoch();
      }
    }
  }

  function testFuzz_ValidatorIdsSetIsUnique_getValidatorIds(
    uint256 wrapUpEpochCount,
    uint256 wrapUpPeriodCount
  ) external {
    wrapUpEpochCount = bound(wrapUpEpochCount, 1, 10);
    wrapUpPeriodCount = bound(wrapUpPeriodCount, 1, 5);

    for (uint256 i; i < wrapUpPeriodCount; ++i) {
      LibWrapUpEpoch.wrapUpPeriods({ times: 1, shouldSubmitBeacon: false });

      for (uint256 j; j < wrapUpEpochCount; ++j) {
        address[] memory validatorIds = roninValidatorSet.getValidatorIds();

        for (uint256 m; m < validatorIds.length; ++m) {
          for (uint256 k; k < validatorIds.length; ++k) {
            if (m != k) {
              assertNotEq(validatorIds[m], validatorIds[k], "Validator IDs should be unique");
            }
          }
        }

        LibWrapUpEpoch.wrapUpEpoch();
      }
    }
  }
}
