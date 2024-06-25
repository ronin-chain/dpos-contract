// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { LibArray } from "@ronin/contracts/libraries/LibArray.sol";

contract LibArrayTest is Test {
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
