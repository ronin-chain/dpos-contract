// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../REP-10_Base.t.sol";

contract RoninRandomBeaconXRoninValidatorSetTest is REP10_BaseTest {
  function testConcrete_WrapUpPeriod_MustScatterRewardsToAllCandidates() public {
    vm.deal(address(roninValidatorSet), 10_000_000 ether);
    vm.deal(address(stakingVesting), 100_000_000 ether);

    LibWrapUpEpoch.fastForwardToNextDay();
    LibWrapUpEpoch.wrapUpEpoch();

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

      LibWrapUpEpoch.fastForwardToNextEpoch();
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
