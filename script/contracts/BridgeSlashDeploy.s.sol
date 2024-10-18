// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IBridgeSlash } from "src/interfaces/bridge/IBridgeSlash.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";
import { Contract } from "../utils/Contract.sol";

contract BridgeSlashDeploy is RoninMigration {
  function _defaultArguments() internal virtual override returns (bytes memory) { }

  function run() public returns (IBridgeSlash) {
    return IBridgeSlash(_deployProxy(Contract.BridgeSlash.key()));
  }
}
