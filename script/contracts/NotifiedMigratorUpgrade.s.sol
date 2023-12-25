// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibProxy } from "foundry-deployment-kit/libraries/LibProxy.sol";
import { ConditionalImplementControl } from
  "@ronin/contracts/extensions/version-control/ConditionalImplementControl.sol";
import { RoninMigration } from "../RoninMigration.s.sol";
import { Contract } from "../utils/Contract.sol";

contract NotifiedMigratorUpgrade is RoninMigration {
  using LibProxy for address payable;

  function _defaultArguments() internal virtual override returns (bytes memory) { }

  function run(Contract contractType, bytes[] calldata callDatas) public virtual returns (address payable) {
    address payable proxy = config.getAddressFromCurrentNetwork(contractType.key());
    address proxyAdmin = proxy.getProxyAdmin();
    address prevImpl = proxy.getProxyImplementation();
    address newImpl = _deployLogic(contractType.key());
    address notifier = config.getAddressFromCurrentNetwork(Contract.RoninValidatorSet.key());
    (address switcher,) = _deployRaw(
      config.getContractName(Contract.NotifiedMigrator.key()), abi.encode(proxy, prevImpl, newImpl, notifier)
    );
    _upgradeRaw(proxyAdmin, proxy, switcher, abi.encodeCall(ConditionalImplementControl.setCallDatas, (callDatas)));
    return proxy;
  }
}
