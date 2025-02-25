// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninMigration } from "script/RoninMigration.s.sol";
import { ISharedArgument } from "script/interfaces/ISharedArgument.sol";
import { Contract } from "script/utils/Contract.sol";
import { IBaseFeeTreasury } from "src/interfaces/basefee-treasury/IBaseFeeTreasury.sol";

contract RoninBaseFeeTreasuryDeploy is RoninMigration {
  function run() public returns (IBaseFeeTreasury) {
    return IBaseFeeTreasury(_deployProxy(Contract.RoninBaseFeeTreasury.key()));
  }
}
