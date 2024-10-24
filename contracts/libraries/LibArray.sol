// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IndexMap } from "./LibIndexMap.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title LibArray
 * @dev A library for array-related utility functions in Solidity.
 */
library LibArray {
  /**
   * @dev Error indicating a length mismatch between two arrays.
   */
  error ErrLengthMismatch();

  /**
   * @dev Error thrown when a duplicated element is detected in an array.
   * @param msgSig The function signature that invoke the error.
   */
  error ErrDuplicated(bytes4 msgSig);

  /**
   * @dev Add two arrays of uint256 values element-wise and return the sum.
   * @param arr1 The first array of uint256 values.
   * @param arr2 The second array of uint256 values.
   * @return res The result of summing each element of two arrays.
   * @return total The sum value of two arrays.
   */
  function addAndSum(
    uint256[] memory arr1,
    uint256[] memory arr2
  ) internal pure returns (uint256[] memory res, uint256 total) {
    uint256 length = arr1.length;
    if (length != arr2.length) revert ErrLengthMismatch();

    res = new uint256[](length);
    for (uint256 i; i < length; ++i) {
      res[i] = arr1[i] + arr2[i];
      total += res[i];
    }
  }

  /**
   * @dev Add two arrays of uint256 values element-wise.
   * @param arr1 The first array of uint256 values.
   * @param arr2 The second array of uint256 values.
   * @return res The sum of the two arrays.
   */
  function add(uint256[] memory arr1, uint256[] memory arr2) internal pure returns (uint256[] memory res) {
    uint256 length = arr1.length;
    if (length != arr2.length) revert ErrLengthMismatch();

    res = new uint256[](length);
    for (uint256 i; i < length; ++i) {
      res[i] = arr1[i] + arr2[i];
    }
  }

  /**
   * @dev Calculates the sum of an array of uint256 values.
   *
   * Modified from: https://docs.soliditylang.org/en/v0.8.25/assembly.html#example
   *
   * @param data The array of uint256 values for which the sum is calculated.
   * @return result The sum of the provided array.
   */
  function sum(uint256[] memory data) internal pure returns (uint256 result) {
    assembly ("memory-safe") {
      // Load the length (first 32 bytes)
      let len := mload(data)
      let dataElementLocation := add(data, 0x20)

      // Iterate until the bound is not met.
      for { let end := add(dataElementLocation, mul(len, 0x20)) } lt(dataElementLocation, end) {
        dataElementLocation := add(dataElementLocation, 0x20)
      } { result := add(result, mload(dataElementLocation)) }
    }
  }

  /**
   * @dev Returns whether or not there's a duplicate. Runs in O(n^2).
   * @param A Array to search
   * @return Returns true if duplicate, false otherwise
   */
  function hasDuplicate(address[] memory A) internal pure returns (bool) {
    uint256 length = A.length;
    if (length == 0) return false;

    unchecked {
      for (uint256 i; i < length - 1; ++i) {
        for (uint256 j = i + 1; j < length; ++j) {
          if (A[i] == A[j]) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /**
   * @notice This method normalized the descending-sorted array `values` so that all elements in the `values`
   * are still in correct order, have 'relative' diffs and not greater than `sum(normed(values))/divisor`.
   * Returns the `normSum` and the `pivot` after normalizing the array.
   *
   * @dev Given a tuple of `(a, s, k)` and divisor `d` where:
   *    - `a` is the array of values of length `n`,
   *    - `s` is the sum of the array,
   *    - `k` is the pivot value, `k = s / d` initially.
   *
   * This method normalizes `a` to `a'` such that:
   *    (1) Elements in `a` and `a'` are decreased relatively
   *    (2) `k' = (s' / d)` and `∀x ∈ a': x ≤ k'`
   *
   * Algorithm:
   *    1. Init `s = sum(a)`, `k = s/d`.
   *    2. While `k` changes:
   *       * Replace all `a[i] > k` by `k`
   *       * k := sum(unchanged(a[i])) / (d - count(changed(a[i])))
   *
   * For example:
   *    Input:
   *      a = [100, 70, 20, 15, 3]
   *      d = 3
   *    Calculation:
   *      Init:    a = [ 100,  70,  20,  15,  3 ];    s = 208;   k = 69
   *      Round 1: a = [  69,  69,  20,  15,  3 ];    s = 177;   k = 38
   *      Round 2: a = [  38,  38,  20,  15,  3 ];    s = 114;   k = 38
   *
   *      The calculation stop since all elements in a is ≤ k, in other words, `k` is unchanged.
   *    Output:
   *      s = 114
   *      k = 38
   *
   * Implementation denotes:
   *    `pivot`: k
   *    `left`:  to-be-changed elements
   *    `right`: unchanged elements
   *
   *    Input:
   *                     pivot
   *                       v
   *            --*-----*--|--------*---------*--------*------
   *              ^     ^           ^         ^        ^
   *              a[0]  a[1]        a[2]      a[3]     a[4]
   *
   *    Output:
   *                         pivot = a[0] = a[1]
   *                           v
   *            ---------------|----*---------*--------*------
   *                                ^         ^        ^
   *                                a[2]      a[3]     a[4]
   *
   * WARNING: This function modifies `cids` and `values`
   */
  function inplaceFindNormalizedSumAndPivot(
    address[] memory cids,
    uint256[] memory values,
    uint256 divisor
  ) internal pure returns (uint256 normSum, uint256 pivot) {
    divisor = Math.min(values.length, divisor);
    inplaceDescSortByValue({ self: cids, values: values });

    uint256 sLeft;
    uint256 nLeft;
    uint256 sRight;
    bool shouldExit;

    normSum = sum(values);
    pivot = normSum / divisor;

    while (!shouldExit) {
      shouldExit = true;

      while (values[nLeft] > pivot) {
        sLeft += values[nLeft++];
        shouldExit = false;
      }

      if (shouldExit) break;

      sRight = normSum - sLeft;
      pivot = sRight / (divisor - nLeft); // Mathematically proven `divisor` is always larger than `nLeft`
      sLeft = pivot * nLeft;
      normSum = sRight + sLeft;
    }
  }

  /**
   * @dev Clips the values in the given array to be within the specified lower and upper bounds.
   *
   * - The input array is modified in place.
   *
   * - Examples:
   * `inplaceClip([1, 2, 3, 4, 5], 2, 4)` => `[2, 2, 3, 4, 4]`
   */
  function inplaceClip(
    uint256[] memory values,
    uint256 lower,
    uint256 upper
  ) internal pure returns (uint256[] memory clippedValues) {
    uint256 length = values.length;

    for (uint256 i; i < length; ++i) {
      if (values[i] < lower) values[i] = lower;
      if (values[i] > upper) values[i] = upper;
    }

    assembly ("memory-safe") {
      clippedValues := values
    }
  }

  /**
   * @dev Returns whether two arrays of addresses are equal or not.
   */
  function isEqual(address[] memory self, address[] memory other) internal pure returns (bool yes) {
    return hash(self) == hash(other);
  }

  /**
   * @dev Hash dynamic size array
   * @param self The array of uint256
   * @return digest The hash result of the array
   */
  function hash(uint256[] memory self) internal pure returns (bytes32 digest) {
    assembly ("memory-safe") {
      digest := keccak256(add(self, 0x20), mul(mload(self), 0x20))
    }
  }

  function hash(address[] memory self) internal pure returns (bytes32 digest) {
    return hash(toUint256s(self));
  }

  /**
   * @dev Return the concatenated array (uint256) from a and b.
   */
  function concat(uint256[] memory a, uint256[] memory b) internal pure returns (uint256[] memory c) {
    unchecked {
      uint256 lengthA = a.length;
      uint256 lengthB = b.length;

      if (lengthA == 0) return b;
      if (lengthB == 0) return a;

      c = new uint256[](lengthA + lengthB);

      uint256 i;

      for (; i < lengthA;) {
        c[i] = a[i];
        ++i;
      }
      for (uint256 j; j < lengthB;) {
        c[i] = b[j];
        ++i;
        ++j;
      }
    }
  }

  /**
   * @dev Return the concatenated array (address) from a and b.
   */
  function concat(address[] memory a, address[] memory b) internal pure returns (address[] memory c) {
    return unsafeToAddresses(concat(toUint256s(a), toUint256s(b)));
  }

  /**
   * @dev Converts an array of address to an array of uint256.
   */
  function toUint256s(address[] memory self) internal pure returns (uint256[] memory uint256s) {
    assembly ("memory-safe") {
      uint256s := self
    }
  }

  /**
   * @dev Converts an array of uint256 to an array of uint96.
   */
  function unsafeToUint96s(uint256[] memory self) internal pure returns (uint96[] memory uint96s) {
    assembly ("memory-safe") {
      uint96s := self
    }
  }

  /**
   * @dev Converts an array of uint256 to an array of address.
   */
  function unsafeToAddresses(uint256[] memory self) internal pure returns (address[] memory addresses) {
    assembly ("memory-safe") {
      addresses := self
    }
  }

  /**
   * @dev Create an array of indices (an index array) with provided range.
   * @param length The array size
   * @return data an array of indices
   */
  function arange(uint256 length) internal pure returns (uint256[] memory data) {
    unchecked {
      data = new uint256[](length);
      for (uint256 i; i < length; ++i) {
        data[i] = i;
      }
    }
  }

  /**
   * @dev Take elements from an array (uint256) given an array of indices.
   *
   * Inspiration from: https://numpy.org/doc/stable/reference/generated/numpy.take.html
   */
  function take(uint256[] memory self, uint256[] memory ids) internal pure returns (uint256[] memory result) {
    uint256 length = ids.length;
    result = new uint256[](length);
    for (uint256 i; i < length; ++i) {
      result[i] = self[ids[i]];
    }
  }

  /**
   * @dev Take elements from an array (address) given an array of indices.
   */
  function take(address[] memory self, uint256[] memory indices) internal pure returns (address[] memory result) {
    return unsafeToAddresses(take(toUint256s(self), indices));
  }

  /**
   * @dev Pick the top `k` `keys` of type address[] based on their corresponding `values`.
   */
  function pickTopKByValues(
    address[] memory keys,
    uint256[] memory values,
    uint256 k
  ) internal pure returns (address[] memory pickeds) {
    return unsafeToAddresses(pickTopKByValues(toUint256s(keys), values, k));
  }

  /**
   * @dev Picks the top `k` `keys` based on their corresponding `values`.
   *
   * WARNING: The input array size will be changed. Besides, this fn does not guarantee all elements are sorted
   */
  function pickTopKByValues(
    uint256[] memory keys,
    uint256[] memory values,
    uint256 k
  ) internal pure returns (uint256[] memory pickeds) {
    unchecked {
      uint256 length = keys.length;
      if (k >= length) return keys;

      inplaceDescSortByValue(keys, values);
      unsafeResize(keys, k);

      return keys;
    }
  }

  /**
   * @dev Filter the array `keys` by the corresponding `indexMap` with the filter function `filterFn`.
   */
  function filterByIndexMap(
    uint256[] memory keys,
    IndexMap memory indexMap,
    function(uint256, uint256[] memory) pure returns (bool) filterFn
  ) internal pure returns (uint256[] memory filteredKeys) {
    return filterBy(keys, indexMap._inner, filterFn);
  }

  /**
   * @dev Filter the array `keys` by the corresponding value array `values` with the filter function `filterFn`.
   */
  function filterBy(
    uint256[] memory keys,
    uint256[] memory values,
    function(uint256, uint256[] memory) pure returns (bool) filterFn
  ) internal pure returns (uint256[] memory filteredKeys) {
    unchecked {
      uint256 length = keys.length;
      filteredKeys = new uint256[](length);
      uint256 nFiltered;

      for (uint256 i; i < length; ++i) {
        if (filterFn(i, values)) {
          filteredKeys[nFiltered++] = keys[i];
        }
      }

      unsafeResize(filteredKeys, nFiltered);

      return filteredKeys;
    }
  }

  /**
   * @dev Sorts array of uint256 `values`.
   *
   * - Values are sorted in descending order.
   *
   * WARNING This function DOES modifies the original `values`.
   */
  function inplaceDescSort(uint256[] memory values) internal pure returns (uint256[] memory sorted) {
    return inplaceDescQuickSort(values);
  }

  /**
   * @dev Quick sort `values`.
   *
   * - Values are sorted in descending order.
   *
   * WARNING This function modify `values`
   */
  function inplaceDescQuickSort(uint256[] memory values) internal pure returns (uint256[] memory sorted) {
    uint256 length = values.length;
    unchecked {
      if (length > 1) _inplaceDescQuickSort(values, 0, int256(length - 1));
    }

    assembly ("memory-safe") {
      sorted := values
    }
  }

  /**
   * @dev Internal function to perform quicksort on an `values`.
   *
   * - Values are sorted in descending order.
   *
   * WARNING This function modify `values`
   */
  function _inplaceDescQuickSort(uint256[] memory values, int256 left, int256 right) private pure {
    unchecked {
      if (left < right) {
        if (left == right) return;
        int256 i = left;
        int256 j = right;
        uint256 pivot = values[uint256(left + right) >> 1];

        while (i <= j) {
          while (pivot < values[uint256(i)]) ++i;
          while (pivot > values[uint256(j)]) --j;

          if (i <= j) {
            (values[uint256(i)], values[uint256(j)]) = (values[uint256(j)], values[uint256(i)]);
            ++i;
            --j;
          }
        }

        if (left < j) _inplaceDescQuickSort(values, left, j);
        if (i < right) _inplaceDescQuickSort(values, i, right);
      }
    }
  }

  /**
   * @dev Sorts array of addresses `self` based on `values`.
   *
   * - Values are sorted in descending order.
   *
   * WARNING This function DOES modifies the original `self` and `values`.
   */
  function inplaceDescSortByValue(
    address[] memory self,
    uint256[] memory values
  ) internal pure returns (address[] memory sorted) {
    return unsafeToAddresses(inplaceDescQuickSortByValue(toUint256s(self), values));
  }

  /**
   * @dev Resize a memory array.
   *
   * WARNING: The new length of the array should not be greater than the current length to avoid collision with other already allocated memory.
   */
  function unsafeResize(uint256[] memory self, uint256 length) internal pure returns (uint256[] memory resized) {
    assembly ("memory-safe") {
      resized := self
      mstore(resized, length)
    }
  }

  /**
   * @dev Resize a memory address array.
   *
   * WARNING: The new length of the array should not be greater than the current length to avoid collision with other already allocated memory.
   */
  function unsafeResize(address[] memory self, uint256 length) internal pure returns (address[] memory resized) {
    return unsafeToAddresses(unsafeResize(toUint256s(self), length));
  }

  /**
   * @dev Sorts `self` based on `values`.
   *
   * - Values are sorted in descending order.
   *
   * WARNING This function DOES modifies the original `self` and `values`.
   */
  function inplaceDescSortByValue(
    uint256[] memory self,
    uint256[] memory values
  ) internal pure returns (uint256[] memory sorted) {
    return inplaceDescQuickSortByValue(self, values);
  }

  /**
   * @dev Quick sort `self` based on `values`.
   *
   * - Values are sorted in descending order.
   *
   * WARNING This function modify `self` and `values`
   */
  function inplaceDescQuickSortByValue(
    uint256[] memory self,
    uint256[] memory values
  ) internal pure returns (uint256[] memory sorted) {
    uint256 length = self.length;
    if (length != values.length) revert ErrLengthMismatch();
    unchecked {
      if (length > 1) _inplaceDescQuickSortByValue(self, values, 0, int256(length - 1));
    }

    assembly ("memory-safe") {
      sorted := self
    }
  }

  /**
   * @dev Internal function to perform quicksort on an `values` based on a corresponding `arr`.
   *
   * - Values are sorted in descending order.
   *
   * WARNING This function modify `arr` and `values`
   */
  function _inplaceDescQuickSortByValue(
    uint256[] memory arr,
    uint256[] memory values,
    int256 left,
    int256 right
  ) private pure {
    unchecked {
      if (left == right) return;
      int256 i = left;
      int256 j = right;
      uint256 pivot = values[uint256(left + right) >> 1];

      while (i <= j) {
        while (pivot < values[uint256(i)]) ++i;
        while (values[uint256(j)] < pivot) --j;

        if (i <= j) {
          (arr[uint256(i)], arr[uint256(j)]) = (arr[uint256(j)], arr[uint256(i)]);
          (values[uint256(i)], values[uint256(j)]) = (values[uint256(j)], values[uint256(i)]);
          ++i;
          --j;
        }
      }

      if (left < j) _inplaceDescQuickSortByValue(arr, values, left, j);
      if (i < right) _inplaceDescQuickSortByValue(arr, values, i, right);
    }
  }
}
