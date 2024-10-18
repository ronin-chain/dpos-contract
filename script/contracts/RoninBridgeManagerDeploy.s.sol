// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninMigration } from "script/RoninMigration.s.sol";

import { Contract } from "../utils/Contract.sol";
import { BridgeSlashDeploy } from "./BridgeSlashDeploy.s.sol";
import { IBridgeManager } from "src/interfaces/bridge/IBridgeManager.sol";
import { GlobalProposal } from "src/libraries/GlobalProposal.sol";

contract RoninBridgeManagerDeploy is RoninMigration {
  function _injectDependencies() internal override {
    _setDependencyDeployScript(Contract.BridgeSlash.key(), address(new BridgeSlashDeploy()));
  }

  function _defaultArguments() internal override returns (bytes memory args) {
    // register BridgeSlash as callback receiver
    address[] memory callbackRegisters = new address[](1);
    // load BridgeSlash address
    callbackRegisters[0] = loadContractOrDeploy(Contract.BridgeSlash.key());

    address[] memory operators = new address[](1);
    operators[0] = makeAccount("detach-operator-1").addr;

    address[] memory governors = new address[](1);
    governors[0] = makeAccount("detach-governor-1").addr;

    uint96[] memory weights = new uint96[](1);
    weights[0] = 100;

    GlobalProposal.TargetOption[] memory targetOptions;
    address[] memory targets;

    return abi.encode(
      2, //DEFAULT_NUMERATOR,
      4, //DEFAULT_DENOMINATOR,
      block.chainid,
      5 minutes, // DEFAULT_EXPIRY_DURATION,
      loadContract(Contract.RoninGatewayV3.key()),
      callbackRegisters,
      operators,
      governors,
      weights,
      targetOptions,
      targets
    );
  }

  function run() public returns (IBridgeManager) {
    return IBridgeManager(_deployImmutable(Contract.RoninBridgeManager.key()));
  }
}
