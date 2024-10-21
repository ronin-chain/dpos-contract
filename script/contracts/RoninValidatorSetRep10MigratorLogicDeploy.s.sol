// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninRandomBeaconDeploy } from "./RoninRandomBeaconDeploy.s.sol";
import { RoninValidatorSetDeploy } from "./RoninValidatorSetDeploy.s.sol";
import { IMigrationScript } from "@fdk/interfaces/IMigrationScript.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";
import { ISharedArgument } from "script/interfaces/ISharedArgument.sol";
import { Contract } from "script/utils/Contract.sol";
import { RoninValidatorSetREP10Migrator } from "src/ronin/validator/migrations/RoninValidatorSetREP10Migrator.sol";

contract RoninValidatorSetREP10MigratorLogicDeploy is RoninMigration {
  using LibProxy for *;

  uint256 private _activatedAtPeriod;
  address private _prevImpl;

  function _injectDependencies() internal virtual override {
    _setDependencyDeployScript(Contract.RoninValidatorSet.key(), new RoninValidatorSetDeploy());
    _setDependencyDeployScript(Contract.RoninRandomBeacon.key(), new RoninRandomBeaconDeploy());
  }

  function overrideActivatedAtPeriod(
    uint256 activatedAtPeriod
  ) public returns (RoninValidatorSetREP10MigratorLogicDeploy) {
    _activatedAtPeriod = activatedAtPeriod;
    return RoninValidatorSetREP10MigratorLogicDeploy(address(this));
  }

  function overridePrevImpl(
    address prevImpl
  ) public returns (RoninValidatorSetREP10MigratorLogicDeploy) {
    _prevImpl = prevImpl;
    return RoninValidatorSetREP10MigratorLogicDeploy(address(this));
  }

  function _logicArgs() internal returns (bytes memory args) {
    ISharedArgument.RoninValidatorSetREP10MigratorParam memory param =
      config.sharedArguments().roninValidatorSetREP10Migrator;

    address payable currProxy = loadContractOrDeploy(Contract.RoninValidatorSet.key());
    address prevImpl = _prevImpl == address(0x0) ? currProxy.getProxyImplementation() : _prevImpl;
    address newImpl = _deployLogic(Contract.RoninValidatorSet.key());
    uint256 activatedAtPeriod = _activatedAtPeriod > 0 ? _activatedAtPeriod : param.activatedAtPeriod;
    args = abi.encode(currProxy, prevImpl, newImpl, activatedAtPeriod);
  }

  function run() public virtual returns (address instance) {
    instance = _deployLogic(Contract.RoninValidatorSetREP10Migrator.key(), _logicArgs());
  }
}
