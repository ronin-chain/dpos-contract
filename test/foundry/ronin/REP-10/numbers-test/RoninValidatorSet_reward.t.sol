// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./REP-10_Light_Base.t.sol";

contract RoninValidatorSetTest_RewardTest is REP10_Light_BaseTest {
  function setUp() public override {
    super.setUp();
  }

  function testConcrete_WrapUpPeriod_MustShareRewardCorrectly() public {
    vm.deal(address(roninValidatorSet), 10_000_000 ether);
    vm.deal(address(stakingVesting), 100_000_000 ether);

    LibWrapUpEpoch.fastForwardToNextDay();
    LibWrapUpEpoch.wrapUpEpoch();

    address[] memory allCids = roninValidatorSet.getValidatorCandidateIds();
    address[] memory admins = profile.getManyId2Admin(allCids);
    TConsensus[] memory allCssLst = roninValidatorSet.getValidatorCandidates();

    uint256[] memory balancesBefore = new uint256[](allCids.length);
    for (uint256 i; i < allCids.length; i++) {
      balancesBefore[i] = admins[i].balance;
    }

    uint256 currPeriod = roninValidatorSet.currentPeriod();
    uint256 submittedBlockCount;

    // for (uint256 i; i < 4; ++i) {
      for (uint256 i; i < 144; ++i) {
      TConsensus[] memory currValidators = roninValidatorSet.getValidators();
      uint256 currBlockNumber = vm.getBlockNumber();

      for (uint256 k; k < 200; ++k) {
        uint j = k % currValidators.length;
        vm.coinbase(TConsensus.unwrap(currValidators[j]));
        // Random from 0.5 -> 1 RON using vm.unixTime();
        // uint256 reward = (vm.unixTime() % 0.5 ether) + 0.5 ether;
        uint256 reward = 0;

        vm.roll(currBlockNumber + k);
        vm.deal(TConsensus.unwrap(currValidators[j]), reward);
        vm.prank(TConsensus.unwrap(currValidators[j]));
        roninValidatorSet.submitBlockReward{ value: reward }();
        submittedBlockCount++;

        // console.log("Timestampppppppppppppp", vm.getBlockTimestamp());

        vm.prank(TConsensus.unwrap(currValidators[j]));
        // fastFinalityTracking.recordFinality(currValidators);
        fastFinalityTracking.recordFinality(allCssLst);
      }
      // for (uint256 j; j < currValidators.length; ++j) {

      // }

      if (i == 143) {
        console.log("Break for wrap period:", i);
        break;
      }

      // LibWrapUpEpoch.fastForwardToNextEpoch();
      LibWrapUpEpoch.wrapUpEpoch();

      console.log("Current epoch:", roninValidatorSet.epochOf(block.number));
      console.log("Current periodddddddd:", roninValidatorSet.currentPeriod());

      if (currPeriod != roninValidatorSet.currentPeriod()) {
        console.log("Break at epoch:", i);
        revert();
        break;
      }
    }

    // uint256 currBlockNumber = vm.getBlockNumber();

    // TConsensus[] memory currValidators = roninValidatorSet.getValidators();
    // for (uint256 j; j < currValidators.length; ++j) {
    //   vm.coinbase(TConsensus.unwrap(currValidators[j]));
    //   // Random from 0.5 -> 1 RON using vm.unixTime();
    //   uint256 reward = 0 ether;

    //   vm.roll(currBlockNumber + j);
    //   vm.deal(TConsensus.unwrap(currValidators[j]), reward);
    //   vm.prank(TConsensus.unwrap(currValidators[j]));
    //   roninValidatorSet.submitBlockReward{ value: reward }();
    //   vm.prank(TConsensus.unwrap(currValidators[j]));
    //   fastFinalityTracking.recordFinality(currValidators);
    // }

    // LibWrapUpEpoch.wrapUpEpoch();
    // // LibWrapUpEpoch.fastForwardToNextDay();
    // // LibWrapUpEpoch.fastForwardToNextEpoch();
    uint256 nextDayTimestamp = vm.getBlockTimestamp() + 1 days;
    vm.warp(nextDayTimestamp);
    LibWrapUpEpoch.wrapUpEpoch();


    uint256[] memory balancesAfter = new uint256[](allCids.length);

    uint256 balanceChanged;
    uint256 balanceUnchanged;
    uint256 totalAllChanges;

    for (uint256 i = 0; i < admins.length; i++) {
      balancesAfter[i] = admins[i].balance;
      if (balancesAfter[i] > balancesBefore[i]) {
        totalAllChanges += balancesAfter[i] - balancesBefore[i];
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
    console.log("Submitted block count", submittedBlockCount);

    console.log("Expected total all changes", submittedBlockCount * stakingVesting.blockProducerBlockBonus(0));
    console.log("Total all changes", totalAllChanges);

    assertTrue(balanceChanged > maxValidatorNumber, "Balance changed count must be greater than maxValidatorNumber");
  }
}
