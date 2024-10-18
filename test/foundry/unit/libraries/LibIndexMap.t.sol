// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { IndexMap, LibIndexMap } from "src/libraries/LibIndexMap.sol";

contract LibIndexMapTest is Test {
  function testFuzz_CreateIndexMap(uint16 length) external pure {
    IndexMap memory map = LibIndexMap.create(length);
    assertTrue(map._inner.length != 0, "map.length == 0");
  }

  function testFuzz_ShouldNotRecordUnsetIndex_contains(uint16 length, uint16 indexToRecord) external pure {
    IndexMap memory map = LibIndexMap.create(length);

    vm.assume(indexToRecord < length);

    assertFalse(map.contains(indexToRecord), "map.contains(indexToRecord)");
  }

  function testConcrete_shouldStoreIndexCorrectly_contains() external pure {
    uint16 length = 10;
    IndexMap memory map = LibIndexMap.create(length);

    map.set(1);
    map.set(4);
    map.set(3);
    map.set(2);

    assertTrue(map.contains(1), "!map.contains(1)");
    assertTrue(map.contains(4), "!map.contains(4)");
    assertTrue(map.contains(3), "!map.contains(3)");
    assertTrue(map.contains(2), "!map.contains(2)");
  }

  function testConcrete_RevertWhen_IndexGreaterThanValuesLength_set() external {
    uint16 length = 10;
    IndexMap memory map = LibIndexMap.create(length);

    vm.expectRevert();
    map.set(1000);
  }

  function testFuzz_shouldStoreIndexCorrectly_contains(uint256[] calldata values, uint256 indexToRecord) external pure {
    IndexMap memory map = LibIndexMap.create(uint16(values.length));

    vm.assume(indexToRecord < values.length);

    map.set(indexToRecord);

    assertTrue(map.contains(indexToRecord), "!map.contains(indexToRecord)");
  }

  function testFuzz_shouldStoreIndicesCorrectly_contains(
    uint256[] calldata values,
    uint256[] calldata indicesToRecord
  ) external {
    vm.skip(true);
    IndexMap memory map = LibIndexMap.create(uint16(values.length));

    for (uint256 i = 0; i < indicesToRecord.length; i++) {
      vm.assume(indicesToRecord[i] < values.length);
    }

    map.setBatch(indicesToRecord);

    for (uint256 i = 0; i < indicesToRecord.length; i++) {
      assertTrue(map.contains(indicesToRecord[i]), "!map.contains(indicesToRecord[i])");
    }
  }
}
