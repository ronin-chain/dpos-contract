// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../ronin/validator/RoninValidatorSet.sol";
import "../MockPrecompile.sol";

contract MockRoninValidatorSetOverridePrecompile is RoninValidatorSet, MockPrecompile {
  constructor() { }

  function arrangeValidatorCandidates(
    address[] memory _candidates,
    uint256[] memory _trustedWeights,
    uint256 _newValidatorCount,
    uint256 _maxPrioritizedValidatorNumber
  ) external pure returns (address[] memory) {
    _arrangeValidatorCandidates(_candidates, _trustedWeights, _newValidatorCount, _maxPrioritizedValidatorNumber);
    return _candidates;
  }
}
