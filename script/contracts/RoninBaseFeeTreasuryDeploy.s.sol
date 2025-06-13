// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { console } from "forge-std/console.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";
import { ISharedArgument } from "script/interfaces/ISharedArgument.sol";
import { Contract } from "script/utils/Contract.sol";
import { IBaseFeeTreasury } from "src/interfaces/basefee-treasury/IBaseFeeTreasury.sol";

contract RoninBaseFeeTreasuryDeploy is RoninMigration {
  IBaseFeeTreasury internal _instance;

  function run() public returns (IBaseFeeTreasury) {
    return _instance = IBaseFeeTreasury(_deployProxy(Contract.RoninBaseFeeTreasury.key()));
  }

  function _postCheck() internal virtual override {
    address governanceAdmin = loadContract(Contract.RoninGovernanceAdmin.key());
    assertEq(LibProxy.getProxyAdmin(address(_instance)), governanceAdmin, "Proxy admin mismatch");
    console.log("Governance Admin", governanceAdmin);
  }

  function _afterRunningScript() internal virtual override {
    // skip initialization checks
  }
}
