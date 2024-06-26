// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IBridgeReward } from "@ronin/contracts/interfaces/bridge/IBridgeReward.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";
import { Contract } from "../utils/Contract.sol";

contract BridgeRewardDeploy is RoninMigration {
  function _defaultArguments() internal virtual override returns (bytes memory) { }

  function run() public returns (IBridgeReward) {
    return IBridgeReward(_deployProxy(Contract.BridgeReward.key()));
  }
}
