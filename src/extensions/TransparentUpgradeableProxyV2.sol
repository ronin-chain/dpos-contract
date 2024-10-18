// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { TransparentUpgradeableProxy } from "@openzeppelin-v4/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ITransparentUpgradeableProxyV2 } from "../interfaces/extensions/ITransparentUpgradeableProxyV2.sol";

contract TransparentUpgradeableProxyV2 is TransparentUpgradeableProxy, ITransparentUpgradeableProxyV2 {
  constructor(
    address _logic,
    address admin_,
    bytes memory _data
  ) payable TransparentUpgradeableProxy(_logic, admin_, _data) { }

  /**
   * @inheritdoc ITransparentUpgradeableProxyV2
   */
  function functionDelegateCall(bytes memory _data) public payable ifAdmin {
    address _addr = _implementation();
    assembly {
      let _result := delegatecall(gas(), _addr, add(_data, 32), mload(_data), 0, 0)
      returndatacopy(0, 0, returndatasize())
      switch _result
      case 0 { revert(0, returndatasize()) }
      default { return(0, returndatasize()) }
    }
  }
}
