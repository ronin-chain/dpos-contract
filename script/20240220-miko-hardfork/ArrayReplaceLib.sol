// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console2.sol";

library ArrayReplaceLib {
  function replace(uint[] memory src, uint[] memory dst, uint where) internal pure returns (uint256[] memory out) {
    require(dst.length + where <= src.length, "ArrayReplaceLib: invalid input");
    out = new uint[](src.length);
    for (uint i; i < where; i++) {
      out[i] = src[i];
    }

    for (uint i = 0; i < dst.length; i++) {
      out[where++] = dst[i];
    }
  }

  function replace(bytes[] memory src, bytes[] memory dst, uint where) internal pure returns (bytes[] memory out) {
    require(dst.length + where <= src.length, "ArrayReplaceLib: invalid input");
    out = new bytes[](src.length);
    for (uint i; i < where; i++) {
      out[i] = src[i];
    }

    for (uint i = 0; i < dst.length; i++) {
      out[where++] = dst[i];
    }
  }

  function replace(address[] memory src, address[] memory dst, uint where) internal pure returns (address[] memory out) {
    require(dst.length + where <= src.length, "ArrayReplaceLib: invalid input");

    out = new address[](src.length);
    for (uint i; i < where; i++) {
      out[i] = src[i];
    }

    for (uint i = 0; i < dst.length; i++) {
      out[where++] = dst[i];
    }
  }
}
