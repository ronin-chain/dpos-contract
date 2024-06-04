// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { RoninValidatorSetTimedMigrator } from
  "@ronin/contracts/ronin/validator/migrations/RoninValidatorSetTimedMigrator.sol";
import { RoninValidatorSet } from "@ronin/contracts/ronin/validator/RoninValidatorSet.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";
import { ProxyInterface, UpgradeInfo, LibDeploy, DeployInfo } from "@fdk/libraries/LibDeploy.sol";
import { Contract } from "../utils/Contract.sol";
import { FastFinalityTrackingDeploy } from "./FastFinalityTrackingDeploy.s.sol";

contract RoninValidatorSetTimedMigratorUpgrade is RoninMigration {
  using LibProxy for address payable;

  function _injectDependencies() internal override {
    _setDependencyDeployScript(Contract.FastFinalityTracking.key(), address(new FastFinalityTrackingDeploy()));
  }

  function _defaultArguments() internal virtual override returns (bytes memory) { }

  function run() public returns (RoninValidatorSet) {
    address payable proxy = loadContract(Contract.RoninValidatorSet.key());
    address prevImpl = proxy.getProxyImplementation();
    address newImpl = _deployLogic(Contract.RoninValidatorSet.key());
    address switcher = _deployLogic(Contract.RoninValidatorSetTimedMigrator.key(), abi.encode(proxy, prevImpl, newImpl));

    bytes[] memory callDatas = new bytes[](2);
    callDatas[0] = abi.encodeCall(RoninValidatorSet.initializeV2, ());
    callDatas[1] =
      abi.encodeCall(RoninValidatorSet.initializeV3, (loadContractOrDeploy(Contract.FastFinalityTracking.key())));

    UpgradeInfo({
      proxy: proxy,
      logic: switcher,
      callValue: 0,
      callData: abi.encodeCall(RoninValidatorSetTimedMigrator.initialize, (callDatas)),
      shouldPrompt: true,
      proxyInterface: ProxyInterface.Transparent,
      upgradeCallback: this.upgradeCallback,
      shouldUseCallback: true
    }).upgrade();

    return RoninValidatorSet(proxy);
  }
}
