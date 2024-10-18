// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IRoninValidatorSet } from "src/interfaces/validator/IRoninValidatorSet.sol";
import { IFastFinalityTracking } from "src/interfaces/IFastFinalityTracking.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";
import { IStaking } from "src/interfaces/staking/IStaking.sol";
import { Contract } from "script/utils/Contract.sol";
import { LibWrapUpEpoch } from "script/shared/libraries/LibWrapUpEpoch.sol";
import { console } from "forge-std/console.sol";
import { TConsensus } from "src/udvts/Types.sol";

contract Migration__03_Propose_HotFix_Testnet_Release_V0_8_1C is RoninMigration {
  IStaking public staking;
  IRoninValidatorSet public validatorSet;
  IFastFinalityTracking public fastFinalityTracking;

  function run() public {
    staking = IStaking(loadContract(Contract.Staking.key()));
    validatorSet = IRoninValidatorSet(loadContract(Contract.RoninValidatorSet.key()));
    fastFinalityTracking = IFastFinalityTracking(loadContract(Contract.FastFinalityTracking.key()));

    _upgradeProxy(Contract.FastFinalityTracking.key());
    uint256 currPeriod = validatorSet.currentPeriod();
    console.log("Period Current", currPeriod);

    LibWrapUpEpoch.wrapUpPeriods({ times: 1, shouldSubmitBeacon: false });

    address[] memory allCids = validatorSet.getValidatorCandidateIds();
    TConsensus[] memory allConsensuses = validatorSet.getValidatorCandidates();
    uint256[] memory stakedAmounts = staking.getManyStakingTotalsById(allCids);

    vm.prank(block.coinbase);
    fastFinalityTracking.recordFinality(allConsensuses);

    currPeriod = validatorSet.currentPeriod();
    console.log("Period Tomorrow", currPeriod);

    uint256 normSum = fastFinalityTracking.getNormalizedSum(currPeriod);
    uint256[] memory normalizedStake = new uint256[](allCids.length);
    for (uint256 i; i < allCids.length; ++i) {
      normalizedStake[i] = fastFinalityTracking.getNormalizedStake(currPeriod, allCids[i]);
    }

    console.log("Norm Sum", normSum);
    for (uint256 i; i < allCids.length; ++i) {
      console.log(
        string.concat(
          vm.toString(allCids[i]),
          " Staked Amount ",
          vm.toString(stakedAmounts[i]),
          " Normalized Stake ",
          vm.toString(normalizedStake[i])
        )
      );
    }
  }
}
