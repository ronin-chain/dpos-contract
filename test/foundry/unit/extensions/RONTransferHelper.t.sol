// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { SafeL2 } from "@safe/contracts/SafeL2.sol";
import { MockRONTransferHelperConsumer_Berlin } from
  "test/foundry/mocks/extensions/MockRONTransferHelperConsumer_Berlin.sol";
import { MockRONTransferHelperConsumer_Istanbul } from
  "test/foundry/mocks/extensions/MockRONTransferHelperConsumer_Istanbul.sol";

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

  function testFuzz_RevertIf_SendIstanbulGasStipened_ToMultisigWallet_OnBerlin(
    uint256 value
  ) public {
    vm.skip(true);
    vm.deal(address(istanbulRONTransfer), value);

    vm.expectRevert();
    istanbulRONTransfer.sendRONLimitGas(payable(multisig), value);
  }

  function testFuzz_SendBerlinGasStipened_ToMultisigWallet_OnBerlin(
    uint256 value
  ) public {
    vm.deal(address(berlinRONTransfer), value);

    berlinRONTransfer.sendRONLimitGas(payable(multisig), value);
  }
}
