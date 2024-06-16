// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../REP-10_Base.t.sol";

contract RoninRandomBeaconXRoninValidatorSetTest is REP10_BaseTest {
  function testFuzz_getBlockProducers_And_getValidators_MustBeTheSame(uint16 wrapUpEpochCount) external {
    vm.deal(address(roninValidatorSet), 10_000_000 ether);
    vm.deal(address(stakingVesting), 100_000_000 ether);
    vm.assume(wrapUpEpochCount > 0 && wrapUpEpochCount < 400);

    for (uint16 i; i < wrapUpEpochCount; i++) {
      LibWrapUpEpoch.wrapUpEpoch();

      assertEq(
        keccak256(abi.encode(roninValidatorSet.getValidators())),
        keccak256(abi.encode(roninValidatorSet.getBlockProducers())),
        "Block producers and validators must be the same"
      );
    }
  }

  function testConcrete_NotIncludeRevokedCandidates_execWrapUpBeaconPeriod() public {
    vm.deal(address(roninValidatorSet), 10_000_000 ether);
    vm.deal(address(stakingVesting), 100_000_000 ether);

    LibWrapUpEpoch.wrapUpEpoch();

    TConsensus[] memory allConsensuses = roninValidatorSet.getValidatorCandidates();
    address[] memory allCids = roninValidatorSet.getValidatorCandidateIds();
    address[] memory admins = profile.getManyId2Admin(allCids);

    uint256 revokeCount = 5;
    address[] memory revokedCids = new address[](revokeCount);
    address[] memory revokedAdmins = new address[](revokeCount);
    TConsensus[] memory revokedConsensuses = new TConsensus[](revokeCount);

    for (uint256 i; i < revokeCount; i++) {
      revokedAdmins[i] = admins[i];
      revokedCids[i] = allCids[i];
      revokedConsensuses[i] = allConsensuses[i];
    }

    uint256 minValidatorStakingAmount = staking.minValidatorStakingAmount();
    for (uint256 i; i < revokeCount; i++) {
      (, uint256 stakingAmount,) = staking.getPoolDetail(revokedConsensuses[i]);
      vm.roll(vm.getBlockNumber() + 1);
      vm.prank(address(slashIndicator));
      roninValidatorSet.execSlash({
        cid: revokedCids[i],
        newJailedUntil: 0,
        slashAmount: stakingAmount - minValidatorStakingAmount + 1 ether,
        cannotBailout: false
      });

      (, stakingAmount,) = staking.getPoolDetail(revokedConsensuses[i]);
      assertTrue(
        stakingAmount < minValidatorStakingAmount, "Staking amount must be less than minValidatorStakingAmount"
      );
    }

    vm.recordLogs();
    LibWrapUpEpoch.wrapUpPeriod();
    VmSafe.Log[] memory logs = vm.getRecordedLogs();

    for (uint256 i; i < logs.length; ++i) {
      if (
        logs[i].emitter == address(roninValidatorSet)
          && logs[i].topics[0] == ICandidateManager.CandidateTopupDeadlineUpdated.selector
      ) {
        address cid = address(bytes20(logs[i].topics[1]));
        uint256 deadline = abi.decode(logs[i].data, (uint256));
        console.log("cid", cid);
        console.log("deadline", deadline);

        vm.warp(deadline + 1);
        break;
      }
    }

    vm.recordLogs();
    LibWrapUpEpoch.wrapUpPeriod();

    logs = vm.getRecordedLogs();
    address[] memory nonRotatingValidators;
    address[] memory rotatingValidators;
    for (uint256 i; i < logs.length; ++i) {
      if (
        logs[i].emitter == address(roninRandomBeacon)
          && logs[i].topics[0] == LibSortValidatorsByBeacon.ValidatorSetSaved.selector
      ) {
        (,, nonRotatingValidators, rotatingValidators,) =
          abi.decode(logs[i].data, (bool, uint256, address[], address[], address));
        break;
      }
    }

    assertTrue(nonRotatingValidators.length > 0, "Non rotating validators must not be empty");
    assertTrue(rotatingValidators.length > 0, "Rotating validators must not be empty");

    address[] memory pendingCids = LibArray.concat(nonRotatingValidators, rotatingValidators);
    // Assert revoked cids not in nonRotatingValidators and rotatingValidators
    assertTrue(
      !LibArray.hasDuplicate(LibArray.concat(revokedCids, pendingCids)),
      "Revoked cids must not in nonRotatingValidators and rotatingValidators"
    );
  }

  function testFuzz_NotIncludeRevokedCandidates_execWrapUpBeaconPeriod(uint256 revokeCount) public {
    vm.deal(address(roninValidatorSet), 10_000_000 ether);
    vm.deal(address(stakingVesting), 100_000_000 ether);

    LibWrapUpEpoch.wrapUpEpoch();

    TConsensus[] memory allConsensuses = roninValidatorSet.getValidatorCandidates();
    address[] memory allCids = roninValidatorSet.getValidatorCandidateIds();
    address[] memory admins = profile.getManyId2Admin(allCids);
    console.log("Candidate length:", allCids.length);

    revokeCount = bound(revokeCount, 1, 5);
    address[] memory revokedCids = new address[](revokeCount);
    address[] memory revokedAdmins = new address[](revokeCount);
    TConsensus[] memory revokedConsensuses = new TConsensus[](revokeCount);

    for (uint256 i; i < revokeCount; i++) {
      revokedAdmins[i] = admins[i];
      revokedCids[i] = allCids[i];
      revokedConsensuses[i] = allConsensuses[i];
    }

    uint256 minValidatorStakingAmount = staking.minValidatorStakingAmount();
    for (uint256 i; i < revokeCount; i++) {
      (, uint256 stakingAmount,) = staking.getPoolDetail(revokedConsensuses[i]);
      vm.roll(vm.getBlockNumber() + 1);
      vm.prank(address(slashIndicator));
      roninValidatorSet.execSlash({
        cid: revokedCids[i],
        newJailedUntil: 0,
        slashAmount: stakingAmount - minValidatorStakingAmount + 1 ether,
        cannotBailout: false
      });

      (, stakingAmount,) = staking.getPoolDetail(revokedConsensuses[i]);
      assertTrue(
        stakingAmount < minValidatorStakingAmount, "Staking amount must be less than minValidatorStakingAmount"
      );
    }

    vm.recordLogs();
    LibWrapUpEpoch.wrapUpPeriod();
    VmSafe.Log[] memory logs = vm.getRecordedLogs();

    for (uint256 i; i < logs.length; ++i) {
      if (
        logs[i].emitter == address(roninValidatorSet)
          && logs[i].topics[0] == ICandidateManager.CandidateTopupDeadlineUpdated.selector
      ) {
        address cid = address(bytes20(logs[i].topics[1]));
        uint256 deadline = abi.decode(logs[i].data, (uint256));
        console.log("cid", cid);
        console.log("deadline", deadline);

        vm.warp(deadline + 1);
        break;
      }
    }

    vm.recordLogs();
    LibWrapUpEpoch.wrapUpPeriod();

    logs = vm.getRecordedLogs();
    address[] memory nonRotatingValidators;
    address[] memory rotatingValidators;
    for (uint256 i; i < logs.length; ++i) {
      if (
        logs[i].emitter == address(roninRandomBeacon)
          && logs[i].topics[0] == LibSortValidatorsByBeacon.ValidatorSetSaved.selector
      ) {
        (,, nonRotatingValidators, rotatingValidators,) =
          abi.decode(logs[i].data, (bool, uint256, address[], address[], address));
        break;
      }
    }

    assertTrue(nonRotatingValidators.length > 0, "Non rotating validators must not be empty");
    assertTrue(rotatingValidators.length > 0, "Rotating validators must not be empty");

    address[] memory pendingCids = LibArray.concat(nonRotatingValidators, rotatingValidators);
    // Assert revoked cids not in nonRotatingValidators and rotatingValidators
    assertTrue(
      !LibArray.hasDuplicate(LibArray.concat(revokedCids, pendingCids)),
      "Revoked cids must not in nonRotatingValidators and rotatingValidators"
    );
  }

  function testConcrete_WrapUpPeriod_MustScatterRewardsToAllCandidates() public {
    vm.deal(address(roninValidatorSet), 10_000_000 ether);
    vm.deal(address(stakingVesting), 100_000_000 ether);

    LibWrapUpEpoch.wrapUpPeriod();

    address[] memory allCids = roninValidatorSet.getValidatorCandidateIds();
    address[] memory admins = profile.getManyId2Admin(allCids);

    uint256[] memory balancesBefore = new uint256[](allCids.length);
    for (uint256 i; i < allCids.length; i++) {
      balancesBefore[i] = admins[i].balance;
    }

    uint256 currPeriod = roninValidatorSet.currentPeriod();
    for (uint256 i; i < 144; ++i) {
      TConsensus[] memory currValidators = roninValidatorSet.getValidators();
      uint256 currBlockNumber = vm.getBlockNumber();

      for (uint256 j; j < currValidators.length; ++j) {
        vm.coinbase(TConsensus.unwrap(currValidators[j]));
        // Random from 0.5 -> 1 RON using vm.unixTime();
        uint256 reward = (vm.unixTime() % 0.5 ether) + 0.5 ether;

        vm.roll(currBlockNumber + j);
        vm.deal(TConsensus.unwrap(currValidators[j]), reward);
        vm.prank(TConsensus.unwrap(currValidators[j]));
        roninValidatorSet.submitBlockReward{ value: reward }();
      }

      LibWrapUpEpoch.wrapUpEpoch();

      if (currPeriod != roninValidatorSet.currentPeriod()) {
        break;
      }
    }

    uint256[] memory balancesAfter = new uint256[](allCids.length);

    uint256 balanceChanged;
    uint256 balanceUnchanged;

    for (uint256 i = 0; i < admins.length; i++) {
      balancesAfter[i] = admins[i].balance;
      if (balancesAfter[i] > balancesBefore[i]) {
        balanceChanged++;
      } else {
        balanceUnchanged++;
      }
    }

    uint256 maxValidatorNumber = roninValidatorSet.maxValidatorNumber();
    console.log("Max validator count", maxValidatorNumber);
    console.log("Total candidate count", allCids.length);
    console.log("Balance changed count", balanceChanged);
    console.log("Balance unchanged count", balanceUnchanged);

    assertTrue(balanceChanged > maxValidatorNumber, "Balance changed count must be greater than maxValidatorNumber");
  }
}
