// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BridgeSlash } from "@ronin/contracts/ronin/gateway/BridgeSlash.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";

import { Contract } from "../utils/Contract.sol";

contract BridgeSlashDeploy is RoninMigration {
  function _defaultArguments() internal virtual override returns (bytes memory) { }

  function run() public returns (BridgeSlash) {
    return BridgeSlash(_deployProxy(Contract.BridgeSlash.key()));
  }
}
