// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { Test } from "forge-std/Test.sol";
import { Maintenance } from "@ronin/contracts/ronin/Maintenance.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";

contract MaintenanceTest is Test {
  address proxyAdmin;
  Maintenance maintenance;

  function setup() public {
    proxyAdmin = makeAddr("proxy-admin");
    Maintenance logic = new Maintenance();
    TransparentUpgradeableProxyV2 proxy = new TransparentUpgradeableProxyV2(address(logic), proxyAdmin, "");
    maintenance = Maintenance(address(proxy));
  }

  function test_SetUp() external { }
}
