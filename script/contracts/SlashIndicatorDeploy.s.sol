// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ISlashIndicator } from "@ronin/contracts/interfaces/slash-indicator/ISlashIndicator.sol";

import { Contract } from "script/utils/Contract.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";

contract SlashIndicatorDeploy is RoninMigration {
  function _defaultArguments() internal virtual override returns (bytes memory args) { }

  function run() public virtual returns (ISlashIndicator instance) {
    instance = ISlashIndicator(_deployProxy(Contract.SlashIndicator.key()));
  }
}
