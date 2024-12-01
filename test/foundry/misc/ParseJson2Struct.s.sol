// SPDX-License-Identifier: MIT
pragma solidity >=0.7.2 <0.9.0;
pragma abicoder v2;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { ISharedArgument } from "script/interfaces/ISharedArgument.sol";

contract ParseJson2StructTest is Test {
  function setUp() external { }

  function testConcrete_ParseConfigToStruct() external view {
    string memory path = "script/config/config.localhost.json";
    ISharedArgument.SharedParameter memory param =
      abi.decode(vm.parseJson(vm.readFile(path)), (ISharedArgument.SharedParameter));

    assertEq(param.initialOwner, 0x600C9956aD26FB0Be9FA3f81C9555779d7003942, "!initialOwner");
    assertEq(param.slashIndicator.slashUnavailability.unavailabilityTier2Threshold, 10, "!unavailabilityTier2Threshold");
    assertEq(param.slashIndicator.slashUnavailability.unavailabilityTier1Threshold, 5, "!unavailabilityTier1Threshold");
  }
}
