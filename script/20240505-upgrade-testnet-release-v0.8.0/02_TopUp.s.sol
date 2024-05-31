// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";

contract Migration__02_TopUp_Validators is RoninMigration {
  address[] topUpList = [
    0xffA555E4ce3772897182B3bD867B1d7FD5891419,
    0x097FC139ADd8b8b0263E80dB94b672A5F5daec80,
    0x904C5c9e71FaD2dcb851D6Fe74fa6bf26789b627
  ];

  uint256 amount = 1_500_000 ether;

  function run() external {
    uint256 length = topUpList.length;
    require(sender().balance > amount * length, "Insufficient balance");

    for (uint256 i = 0; i < length; i++) {
      address topUp = topUpList[i];
      vm.broadcast(sender());
      payable(topUp).transfer(amount);

      console.log("Top-up address:", topUp);

      assertTrue(topUp.balance >= amount, "Top-up failed");
    }
  }
}
