// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17 <0.9.0;

import { TConsensus } from "@ronin/contracts/udvts/Types.sol";

contract MockValidatorSet {
  uint256 _period;

  function setPeriod(uint256 period) external {
    _period = period;
  }

  function currentPeriod() external view returns (uint256) {
    return _period;
  }

  function getValidatorCandidates() external pure returns (address[] memory) {
    return new address[](0);
  }

  function isCandidateAdmin(TConsensus /*consensus*/, address /*admin*/) external pure returns (bool) {
    return true;
  }

  function isCandidateAdmin(address /*cid*/, address /*admin*/) external pure returns (bool) {
    return true;
  }
}
