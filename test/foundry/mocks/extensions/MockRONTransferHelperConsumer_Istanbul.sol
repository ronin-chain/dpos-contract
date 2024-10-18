// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { RONTransferHelper } from "@ronin/contracts/extensions/RONTransferHelper.sol";

contract MockRONTransferHelperConsumer_Istanbul is RONTransferHelper {
  uint256 public constant DEFAULT_ADDITION_GAS = 1200;

  function sendRONLimitGas(address payable recipient, uint256 amount) public {
    _unsafeSendRONLimitGas(recipient, amount, DEFAULT_ADDITION_GAS);
  }
}
