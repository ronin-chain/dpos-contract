// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../REP-10_Base.t.sol";

contract REP_10_FastFinalityTrackingTest is REP10_BaseTest {
  function testFuzz_recordVoters_ScoresNeverZero(uint256 numPick) external {
    TConsensus[] memory allConsensuses = roninValidatorSet.getValidatorCandidates();
    numPick = bound(numPick, 1, allConsensuses.length);

    // Shuffle all validators
    for (uint256 i = allConsensuses.length - 1; i > 0; i--) {
      uint256 j = vm.unixTime() % (i + 1);
      TConsensus temp = allConsensuses[i];
      allConsensuses[i] = allConsensuses[j];
      allConsensuses[j] = temp;
    }

    // Pick random validators
    TConsensus[] memory pickedConsensuses = new TConsensus[](numPick);

    for (uint256 i = 0; i < numPick; i++) {
      pickedConsensuses[i] = allConsensuses[i];
    }

    uint256 currEpoch = roninValidatorSet.epochOf(vm.getBlockNumber());

    // Record voters
    vm.prank(block.coinbase);
    fastFinalityTracking.recordFinality(pickedConsensuses);
    uint256[] memory scores = fastFinalityTracking.getManyFinalityScores(currEpoch, pickedConsensuses);
    // Assert scores never zero
    for (uint256 i; i < numPick; i++) {
      assertTrue(scores[i] > 0, "Score should never be zero");
    }
  }

  function testFuzz_recordVoters_CountsNeverZero(uint256 numPick) external {
    TConsensus[] memory allConsensuses = roninValidatorSet.getValidatorCandidates();
    numPick = bound(numPick, 1, allConsensuses.length);

    // Shuffle all validators
    for (uint256 i = allConsensuses.length - 1; i > 0; i--) {
      uint256 j = vm.unixTime() % (i + 1);
      TConsensus temp = allConsensuses[i];
      allConsensuses[i] = allConsensuses[j];
      allConsensuses[j] = temp;
    }

    // Pick random validators
    TConsensus[] memory pickedConsensuses = new TConsensus[](numPick);

    for (uint256 i = 0; i < numPick; i++) {
      pickedConsensuses[i] = allConsensuses[i];
    }

    uint256 currEpoch = roninValidatorSet.epochOf(vm.getBlockNumber());

    // Record voters
    vm.prank(block.coinbase);
    fastFinalityTracking.recordFinality(pickedConsensuses);
    uint256[] memory counts = fastFinalityTracking.getManyFinalityVoteCounts(currEpoch, pickedConsensuses);
    // Assert counts never zero
    for (uint256 i; i < numPick; i++) {
      assertTrue(counts[i] > 0, "Count should never be zero");
    }
  }
}
