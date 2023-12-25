// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BridgeReward } from "@ronin/contracts/ronin/gateway/BridgeReward.sol";
import { RoninMigration } from "../RoninMigration.s.sol";
import { Contract } from "../utils/Contract.sol";

contract BridgeRewardDeploy is RoninMigration {
  function _defaultArguments() internal virtual override returns (bytes memory) { }

  function run() public returns (BridgeReward) {
    return BridgeReward(_deployProxy(Contract.BridgeReward.key()));
  }
}
