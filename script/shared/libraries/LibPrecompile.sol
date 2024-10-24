// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibSharedAddress } from "@fdk/libraries/LibSharedAddress.sol";
import { Vm } from "forge-std/Vm.sol";
import { MockPrecompile } from "src/mocks/MockPrecompile.sol";

library LibPrecompile {
  Vm internal constant vm = Vm(LibSharedAddress.VM);

  function deployPrecompile() internal {
    if (address(0x68).code.length != 0 || address(0x6a).code.length != 0) return;

    address mockPrecompile = address(new MockPrecompile());
    vm.etch(address(0x68), mockPrecompile.code);
    vm.makePersistent(address(0x68));
    vm.etch(address(0x6a), mockPrecompile.code);
    vm.makePersistent(address(0x6a));
  }
}
