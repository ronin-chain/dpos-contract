// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { NotifiedMigrator } from "src/ronin/validator/migrations/NotifiedMigrator.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";

import { Contract } from "../utils/Contract.sol";

contract NotifiedMigratorUpgrade is RoninMigration {
  using LibProxy for address payable;

  function _defaultArguments() internal virtual override returns (bytes memory) { }

  function run(Contract contractType, bytes[] calldata callDatas) public virtual returns (address payable) {
    // address payable proxy = loadContract(contractType.key());
    // address proxyAdmin = proxy.getProxyAdmin();
    // address prevImpl = proxy.getProxyImplementation();
    // address newImpl = _deployLogic(contractType.key());
    // address notifier = loadContract(Contract.RoninValidatorSet.key());
    // (address switcher,) = _deployRaw(
    //   config.getContractName(Contract.NotifiedMigrator.key()), abi.encode(proxy, prevImpl, newImpl, notifier)
    // );
    // _upgradeRaw(proxyAdmin, proxy, switcher, abi.encodeCall(NotifiedMigrator.initialize, (callDatas)));
    // return proxy;
  }
}
