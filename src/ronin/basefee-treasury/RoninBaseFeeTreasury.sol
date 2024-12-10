// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Initializable } from "@openzeppelin-v5/contracts/proxy/utils/Initializable.sol";

import { HasProxyAdmin } from "src/extensions/collections/HasProxyAdmin.sol";

import { IBaseFeeTreasury } from "src/interfaces/basefee-treasury/IBaseFeeTreasury.sol";

import { ErrorHandler } from "src/libraries/ErrorHandler.sol";

contract RoninBaseFeeTreasury is Initializable, HasProxyAdmin, IBaseFeeTreasury {
  using ErrorHandler for bool;

  receive() external payable {
    // Allow receiving donations.
  }

  constructor() {
    _disableInitializers();
  }

  /**
   * @inherit IBaseFeeTreasury
   */
  function withdrawTo(address to, uint256 amount) external onlyAdmin {
    (bool success, bytes memory ret) = to.call{ value: amount }("");
    success.handleRevert(0x0, ret);

    emit Withdrawn(msg.sender, to, amount);
  }
}
