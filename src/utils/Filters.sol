// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { IndexMap, LibIndexMap } from "../libraries/LibIndexMap.sol";

/**
 * @dev Checks if the given `index` is not present in the `indexMap`.
 * @param index The index to check.
 * @param indexMap The index map to search in.
 * @return A boolean value indicating whether the `index` is not present in the `indexMap`.
 */
function notInIndexMapFilter(uint256 index, uint256[] memory indexMap) pure returns (bool) {
  return !IndexMap(indexMap).contains(index);
}

/**
 * @dev Checks if a weight at a given index is non-zero.
 * @param index The index of the weight to check.
 * @param trustedWeights The array of weights to check against.
 * @return A boolean indicating whether the weight at the given index is non-zero.
 */
function nonZeroTrustedWeightFilter(uint256 index, uint256[] memory trustedWeights) pure returns (bool) {
  return trustedWeights[index] != 0;
}
