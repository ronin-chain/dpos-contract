// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ISharedArgument } from "script/interfaces/ISharedArgument.sol";
import { RoninValidatorSetREP10Migrator } from
  "@ronin/contracts/ronin/validator/migrations/RoninValidatorSetREP10Migrator.sol";
import { Contract } from "script/utils/Contract.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { RoninValidatorSetDeploy } from "./RoninValidatorSetDeploy.s.sol";
import { RoninRandomBeaconDeploy } from "./RoninRandomBeaconDeploy.s.sol";
import { IMigrationScript } from "@fdk/interfaces/IMigrationScript.sol";

contract RoninValidatorSetREP10MigratorLogicDeploy is RoninMigration {
  using LibProxy for *;

  uint256 private _activatedAtPeriod;

  function _injectDependencies() internal virtual override {
    _setDependencyDeployScript(Contract.RoninValidatorSet.key(), new RoninValidatorSetDeploy());
    _setDependencyDeployScript(Contract.RoninRandomBeacon.key(), new RoninRandomBeaconDeploy());
  }

  function overrideActivatedAtPeriod(uint256 activatedAtPeriod) public returns (IMigrationScript) {
    _activatedAtPeriod = activatedAtPeriod;
    return IMigrationScript(address(this));
  }

  function _logicArgs() internal returns (bytes memory args) {
    ISharedArgument.RoninValidatorSetREP10MigratorParam memory param =
      config.sharedArguments().roninValidatorSetREP10Migrator;

    address payable currProxy = loadContractOrDeploy(Contract.RoninValidatorSet.key());
    address prevImpl = currProxy.getProxyImplementation();
    address newImpl = _deployLogic(Contract.RoninValidatorSet.key());
    uint256 activatedAtPeriod = _activatedAtPeriod > 0 ? _activatedAtPeriod : param.activatedAtPeriod;
    args = abi.encode(currProxy, prevImpl, newImpl, activatedAtPeriod);
  }

  function run() public virtual returns (address instance) {
    instance = _deployLogic(Contract.RoninValidatorSetREP10Migrator.key(), _logicArgs());
  }
}
