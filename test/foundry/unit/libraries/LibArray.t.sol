// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { LibArray } from "src/libraries/LibArray.sol";
import { console } from "forge-std/console.sol";

contract LibArrayTest is Test {
  function testConcrete_findNormalizedPivotAndSum() public pure {
    address[] memory cids = new address[](13);
    for (uint256 i; i < cids.length; ++i) {
      cids[i] = address(uint160(i));
    }
    uint256[] memory stakedAmounts = new uint256[](13);

    stakedAmounts[0] = 17585 ether;
    stakedAmounts[1] = 50090 ether;
    stakedAmounts[2] = 16137 ether;
    stakedAmounts[3] = 14543 ether;
    stakedAmounts[4] = 16855 ether;
    stakedAmounts[5] = 23005 ether;
    stakedAmounts[6] = 15709 ether;
    stakedAmounts[7] = 7988 ether;
    stakedAmounts[8] = 14511 ether;
    stakedAmounts[9] = 14511 ether;
    stakedAmounts[10] = 14501 ether;
    stakedAmounts[11] = 9502 ether;
    stakedAmounts[12] = 15061 ether;

    address[] memory oriCids = new address[](13);
    address[] memory expectedSortedCids = new address[](13);
    expectedSortedCids[0] = 0x0000000000000000000000000000000000000001;
    expectedSortedCids[1] = 0x0000000000000000000000000000000000000005;
    expectedSortedCids[2] = 0x0000000000000000000000000000000000000000;
    expectedSortedCids[3] = 0x0000000000000000000000000000000000000004;
    expectedSortedCids[4] = 0x0000000000000000000000000000000000000002;
    expectedSortedCids[5] = 0x0000000000000000000000000000000000000006;
    expectedSortedCids[6] = 0x000000000000000000000000000000000000000C;
    expectedSortedCids[7] = 0x0000000000000000000000000000000000000003;
    expectedSortedCids[8] = 0x0000000000000000000000000000000000000009;
    expectedSortedCids[9] = 0x0000000000000000000000000000000000000008;
    expectedSortedCids[10] = 0x000000000000000000000000000000000000000A;
    expectedSortedCids[11] = 0x000000000000000000000000000000000000000b;
    expectedSortedCids[12] = 0x0000000000000000000000000000000000000007;
    for (uint256 i; i < 13; ++i) {
      oriCids[i] = cids[i];
    }

    (uint256 normSum, uint256 pivot) = LibArray.inplaceFindNormalizedSumAndPivot(cids, stakedAmounts, 10);
    console.log("Pivot", pivot);

    uint256[] memory expectedSortedStakedAmounts = new uint256[](13);
    expectedSortedStakedAmounts[0] = 50090000000000000000000;
    expectedSortedStakedAmounts[1] = 23005000000000000000000;
    expectedSortedStakedAmounts[2] = 17585000000000000000000;
    expectedSortedStakedAmounts[3] = 16855000000000000000000;
    expectedSortedStakedAmounts[4] = 16137000000000000000000;
    expectedSortedStakedAmounts[5] = 15709000000000000000000;
    expectedSortedStakedAmounts[6] = 15061000000000000000000;
    expectedSortedStakedAmounts[7] = 14543000000000000000000;
    expectedSortedStakedAmounts[8] = 14511000000000000000000;
    expectedSortedStakedAmounts[9] = 14511000000000000000000;
    expectedSortedStakedAmounts[10] = 14501000000000000000000;
    expectedSortedStakedAmounts[11] = 9502000000000000000000;
    expectedSortedStakedAmounts[12] = 7988000000000000000000;
    console.log("Norm Sum", normSum);

    for (uint256 i; i < 13; ++i) {
      console.log("cids", vm.toString(cids[i]), vm.toString(stakedAmounts[i]));
    }
    // Assert Order between stakedAmounts and cids are sorted together in descending order
    for (uint256 i; i < 12; ++i) {
      assertTrue(stakedAmounts[i] >= stakedAmounts[i + 1], "stakedAmounts[i] >= stakedAmounts[i + 1]");
      assertTrue(cids[i] == oriCids[uint256(uint160(cids[i]))], "cids[i] == oriCids[uint256(uint160(cids[i]))]");
    }

    for (uint256 i; i < expectedSortedCids.length; ++i) {
      assertTrue(cids[i] == expectedSortedCids[i], "cids[i] == expectedSortedCids[i]");
      assertTrue(
        stakedAmounts[i] == expectedSortedStakedAmounts[i], "stakedAmounts[i] == expectedSortedStakedAmounts[i]"
      );
    }

    assertEq(pivot, 19612875000000000000000, "incorrect expected pivot");
    assertEq(normSum, 196128750000000000000000, "incorrect expected normSum");
  }

  function testFuzz_AddAndSum(uint256[1000] memory arr1_, uint256[1000] memory arr2_) public pure {
    uint256[] memory arr1 = new uint256[](arr1_.length);
    uint256[] memory arr2 = new uint256[](arr2_.length);
    for (uint256 i; i < arr1.length; ++i) {
      arr1[i] = bound(arr1_[i], 0, type(uint128).max);
      arr2[i] = bound(arr2_[i], 0, type(uint128).max);
    }

    uint256[] memory expected = new uint256[](arr1.length);
    for (uint256 i; i < arr1.length; ++i) {
      expected[i] = arr1[i] + arr2[i];
    }

    (uint256[] memory actual, uint256 totalActual) = LibArray.addAndSum(arr1, arr2);

    for (uint256 i; i < arr1.length; ++i) {
      assertEq(actual[i], expected[i], "actual[i] == expected[i]");
    }

    assertEq(
      keccak256(abi.encodePacked(actual)),
      keccak256(abi.encodePacked(expected)),
      "keccak256(abi.encodePacked(actual)) == keccak256(abi.encodePacked(expected))"
    );

    uint256 expectedSum;
    for (uint256 i; i < arr1.length; ++i) {
      expectedSum += expected[i];
    }

    assertEq(totalActual, expectedSum, "sum(actual) == expectedSum");
  }

  function testFuzz_Add(uint256[1000] memory arr1_, uint256[1000] memory arr2_) public pure {
    uint256[] memory arr1 = new uint256[](arr1_.length);
    uint256[] memory arr2 = new uint256[](arr2_.length);
    for (uint256 i; i < arr1.length; ++i) {
      arr1[i] = bound(arr1_[i], 0, type(uint128).max);
      arr2[i] = bound(arr2_[i], 0, type(uint128).max);
    }

    uint256[] memory expected = new uint256[](arr1.length);
    for (uint256 i; i < arr1.length; ++i) {
      expected[i] = arr1[i] + arr2[i];
    }

    uint256[] memory actual = LibArray.add(arr1, arr2);

    for (uint256 i; i < arr1.length; ++i) {
      assertEq(actual[i], expected[i], "actual[i] == expected[i]");
    }

    assertEq(
      keccak256(abi.encodePacked(actual)),
      keccak256(abi.encodePacked(expected)),
      "keccak256(abi.encodePacked(actual)) == keccak256(abi.encodePacked(expected))"
    );
  }

  function testFuzz_ShouldSortCorrectly_QuickSortDescending(uint256[] memory values) public pure {
    vm.assume(values.length > 0);

    uint256[] memory self = new uint256[](values.length);
    for (uint256 i; i < self.length; ++i) {
      self[i] = i;
    }

    uint256 sumBefore = LibArray.sum(values);
    uint256 sumSelfBefore = LibArray.sum(self);

    LibArray.inplaceDescQuickSortByValue(self, values);

    uint256 sumAfter = LibArray.sum(values);
    uint256 sumSelfAfter = LibArray.sum(self);

    for (uint256 i; i < values.length - 1; ++i) {
      assertTrue(values[i] >= values[i + 1]);
    }

    assertTrue(sumBefore == sumAfter, "sumBefore == sumAfter");
    assertTrue(sumSelfBefore == sumSelfAfter, "sumSelfBefore == sumSelfAfter");
  }

  function testFuzz_ShouldSumCorrectly_sum(uint128[] memory narrowingCastedV) public pure {
    uint256[] memory v;
    assembly {
      v := narrowingCastedV
    }
    uint256 expectedSum;
    for (uint256 i; i < v.length; ++i) {
      expectedSum += v[i];
    }

    assertEq(LibArray.sum(v), expectedSum, "sum(v) == expectedSum");
  }

  function testFuzz_ShouldCastCorrectly_toUint256s(address[] memory addrs) public pure {
    uint256[] memory expected = new uint256[](addrs.length);
    for (uint256 i; i < addrs.length; ++i) {
      expected[i] = uint256(uint160(addrs[i]));
    }

    uint256[] memory actual = LibArray.toUint256s(addrs);

    for (uint256 i; i < addrs.length; ++i) {
      assertEq(actual[i], expected[i], "actual[i] == expected[i]");
    }
  }

  function testFuzz_ShouldHashCorrectly_hashAddressArray(address[] memory v) public pure {
    bytes32 expectedHash = keccak256(abi.encodePacked(v));
    bytes32 actualHash = LibArray.hash(v);

    assertEq(actualHash, expectedHash, "hash(v) == keccak256(abi.encodePacked(v))");
  }

  function testFuzz_ShouldHashCorrectly_hashUint256Array(uint256[] memory v) public pure {
    bytes32 expectedHash = keccak256(abi.encodePacked(v));
    bytes32 actualHash = LibArray.hash(v);

    assertEq(actualHash, expectedHash, "hash(v) == keccak256(abi.encodePacked(v))");
  }
}
