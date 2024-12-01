// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Contract } from "../utils/Contract.sol";
import { FastFinalityTrackingDeploy } from "./FastFinalityTrackingDeploy.s.sol";
import { DeployInfo, LibDeploy, ProxyInterface, UpgradeInfo } from "@fdk/libraries/LibDeploy.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";
import { IRoninValidatorSet } from "src/interfaces/validator/IRoninValidatorSet.sol";
import { RoninValidatorSetTimedMigrator } from "src/ronin/validator/migrations/RoninValidatorSetTimedMigrator.sol";

contract RoninValidatorSetTimedMigratorUpgrade is RoninMigration {
  using LibProxy for address payable;

  function _injectDependencies() internal override {
    _setDependencyDeployScript(Contract.FastFinalityTracking.key(), address(new FastFinalityTrackingDeploy()));
  }

  function _defaultArguments() internal virtual override returns (bytes memory) { }

  function run() public returns (IRoninValidatorSet) {
    address payable proxy = loadContract(Contract.RoninValidatorSet.key());
    address prevImpl = proxy.getProxyImplementation();
    address newImpl = _deployLogic(Contract.RoninValidatorSet.key());
    address switcher = _deployLogic(Contract.RoninValidatorSetTimedMigrator.key(), abi.encode(proxy, prevImpl, newImpl));

    bytes[] memory callDatas = new bytes[](2);
    callDatas[0] = abi.encodeCall(IRoninValidatorSet.initializeV2, ());
    callDatas[1] =
      abi.encodeCall(IRoninValidatorSet.initializeV3, (loadContractOrDeploy(Contract.FastFinalityTracking.key())));

    UpgradeInfo({
      proxy: proxy,
      logic: switcher,
      callValue: 0,
      callData: abi.encodeCall(RoninValidatorSetTimedMigrator.initialize, (callDatas)),
      shouldPrompt: true,
      proxyInterface: ProxyInterface.Transparent,
      upgradeCallback: _upgradeCallback,
      shouldUseCallback: true
    }).upgrade();

    return IRoninValidatorSet(proxy);
  }
}
