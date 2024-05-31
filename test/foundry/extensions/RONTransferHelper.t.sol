// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { SafeL2 } from "safe-smart-account/contracts/SafeL2.sol";
import { MockRONTransferHelperConsumer_Berlin } from "./MockRONTransferHelperConsumer_Berlin.sol";
import { MockRONTransferHelperConsumer_Istanbul } from "./MockRONTransferHelperConsumer_Istanbul.sol";

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

contract RONTransferHelperTest is Test {
  address multisig;
  MockRONTransferHelperConsumer_Berlin berlinRONTransfer;
  MockRONTransferHelperConsumer_Istanbul istanbulRONTransfer;

  function setUp() public {
    multisig = address(new SafeL2());
    berlinRONTransfer = new MockRONTransferHelperConsumer_Berlin();
    istanbulRONTransfer = new MockRONTransferHelperConsumer_Istanbul();
  }

  function testFuzz_RevertIf_SendIstanbulGasStipened_ToMultisigWallet_OnBerlin(uint256 value) public {
    vm.deal(address(istanbulRONTransfer), value);
    address sender = vm.addr(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);

    vm.expectRevert();
    istanbulRONTransfer.sendRONLimitGas(payable(multisig), value);
  }

  function testFuzz_SendBerlinGasStipened_ToMultisigWallet_OnBerlin(uint256 value) public {
    vm.deal(address(berlinRONTransfer), value);
    address sender = vm.addr(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);

    berlinRONTransfer.sendRONLimitGas(payable(multisig), value);
  }
}
