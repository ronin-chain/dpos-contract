// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../REP-10_Base.t.sol";

contract RoninRandomBacon_PickValidatorSet_Test is REP10_BaseTest {
  using StdStyle for *;

  mapping(address cid => uint256 pickCount) internal _pickCountValidatorSet;
  mapping(address cid => uint256 pickCount) internal _pickCountRandomBeacon;

  function testConcrete_LogPickCount_pickValidatorSet() external {
    vm.skip(true);
    LibWrapUpEpoch.wrapUpPeriods({ times: 1, shouldSubmitBeacon: true });
    uint256 wrapUpCount = 1000;

    for (uint256 i; i < wrapUpCount; ++i) {
      LibWrapUpEpoch.wrapUpEpoch();

      address[] memory validatorIds =
        roninRandomBeacon.pickValidatorSetForCurrentPeriod(roninValidatorSet.epochOf(block.number) + 1);
      address[] memory blockProducerIds = roninValidatorSet.getBlockProducerIds();
      for (uint256 j; j < validatorIds.length; ++j) {
        _pickCountValidatorSet[validatorIds[j]]++;
        _pickCountRandomBeacon[blockProducerIds[j]]++;
      }
    }

    // Log pick count
    address[] memory allCids = roninValidatorSet.getValidatorCandidateIds();
    console.log("Number of Candidates:", allCids.length);
    console.log("Number of Wrap Up Epochs:", wrapUpCount);
    for (uint256 i; i < allCids.length; ++i) {
      assertEq(_pickCountValidatorSet[allCids[i]], _pickCountRandomBeacon[allCids[i]], "Pick count should be the same");
      (, uint256 staked,) = staking.getPoolDetail(profile.getId2Consensus(allCids[i]));
      string memory log = string.concat(
        "CID: ".yellow(),
        vm.toString(allCids[i]),
        " Staked: ",
        vm.toString(staked / 1 ether),
        " RON".blue(),
        " Pick Count: ",
        vm.toString(_pickCountValidatorSet[allCids[i]]),
        " Pick Rate: ".yellow(),
        vm.toString(_pickCountValidatorSet[allCids[i]] * 100 / wrapUpCount),
        "%"
      );
      console.log(log);
    }
  }

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
