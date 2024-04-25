// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

struct IndexMap {
  uint256[] _inner;
}

using LibIndexMap for IndexMap global;

/**
 * @title LibIndexMap
 * @author TuDo1403
 * @dev The `IndexMap` is a bitmap that represents the presence or absence of elements at specific indices.
 * It is implemented as an array of uint256 values, where each element in an array is a bitmap which can represent the presence or absence of an element at a particular index.
 * Each element in an array of bitmap can represent the presence or absence of 256 elements.
 * The Presence of a particular index is represented by setting the corresponding bit in the bitmap to 1.
 * Example 1:
 * - Given an array of values: [1, 4, 3, 2]. Returns the indexes of odd numbers.
 * - The values of odd numbers are: [1, 3]. Therefore, the indices of odd numbers are: [0, 2].
 * - However, we can save more gas by using a bitmap to represent the indices of odd numbers.
 * - index 0 is an odd number, so we set the first bit of the bitmap to 1. (bitmap = 0001)
 * - index 2 is an odd number, so we set the third bit of the bitmap to 1. (bitmap = 0100)
 * - The bitmap for the indices of odd number is: b'0001' | b'0100' = b'0101' = 5 in decimal
 * - The bitmap for the indices of odd number is: b'0101' = 5 in decimal
 */
library LibIndexMap {
  /// @dev Throws if the index is out of bitmap length.
  error ErrOutOfRange(uint256 index);

  /// @dev Maximum number of bits in an indexmap slot.
  uint256 internal constant MAX_BIT = 256;

  /**
   * @dev Wraps an array of uint256 values into an IndexMap struct.
   * @param inner The array of uint256 values to wrap.
   * @return The wrapped IndexMap struct.
   */
  function wrap(uint256[] memory inner) internal pure returns (IndexMap memory) {
    return IndexMap(inner);
  }

  /**
   * @dev Creates a indexmap array based on the given number of elements.
   * @param numElement The number of elements to create the indexmap for.
   * @return indexmap The created indexmap array.
   */
  function create(uint16 numElement) internal pure returns (IndexMap memory indexmap) {
    unchecked {
      indexmap._inner = new uint256[](1 + uint256(numElement) / MAX_BIT);
    }
  }

  /**
   * @dev Checks if an index is present in the map.
   * @param indexmap The map to check.
   * @param index The index to check.
   * @return A boolean indicating whether the index is present in the map.
   */
  function contains(IndexMap memory indexmap, uint256 index) internal pure returns (bool) {
    unchecked {
      uint256 size = MAX_BIT;
      // if index is out of range, return false
      if (index >= indexmap._inner.length * size) return false;
      return (indexmap._inner[index / size] & (1 << (index % size))) != 0;
    }
  }

  /**
   * @dev Set of an element in a indexmap based on its value.
   *
   * - The indexmap is updated in place.
   * - Will not check for index out of range of the original array.
   *
   * @param indexmap The indexmap to record the existence of the element.
   * @param index The value to record.
   * @return The updated indexmap with recorded existence of the element.
   */
  function set(IndexMap memory indexmap, uint256 index) internal pure returns (IndexMap memory) {
    unchecked {
      uint256 size = MAX_BIT;
      uint256 pos = index / size;

      if (pos >= indexmap._inner.length) revert ErrOutOfRange(index);

      indexmap._inner[index / size] |= 1 << (index % size);

      return indexmap;
    }
  }

  /**
   * @dev Set of elements in a indexmap based on their values.
   *
   * - The indexmap is updated in place.
   * - Will not check for index out of range of the original array.
   *
   * @param indexmap The indexmap to record the existence of elements.
   * @param indices The array of indices to record.
   * @return The updated indexmap with recorded existence of elements.
   */
  function setBatch(IndexMap memory indexmap, uint256[] memory indices) internal pure returns (IndexMap memory) {
    unchecked {
      uint256 pos;
      uint256 size = MAX_BIT;
      uint256 length = indices.length;
      uint256 bitmapLength = indexmap._inner.length;

      for (uint256 i; i < length; ++i) {
        pos = indices[i] / size;

        if (pos >= bitmapLength) revert ErrOutOfRange(indices[i]);

        indexmap._inner[pos] |= 1 << (indices[i] % size);
      }

      return indexmap;
    }
  }
}
