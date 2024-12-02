// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { IBaseFeeTreasury } from "src/interfaces/basefee-treasury/IBaseFeeTreasury.sol";

contract MaliciousAdmin {
  address public target;
  bytes public data;

  fallback() external payable {
    (bool success,) = target.call(data);
  }

  function setTarget(address target_, bytes memory data_) external {
    target = target_;
    data = data_;
  }
}
