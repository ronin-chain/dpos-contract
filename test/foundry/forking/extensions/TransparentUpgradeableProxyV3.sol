// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

interface ITransparentUpgradeableProxyDeployer {
  function paramLogic() external view returns (address);

  function paramAdmin() external view returns (address);

  function paramExtraData() external view returns (bytes memory);
}

contract TransparentUpgradeableProxyV3 is TransparentUpgradeableProxy {
  constructor()
    payable
    TransparentUpgradeableProxy(
      ITransparentUpgradeableProxyDeployer(msg.sender).paramLogic(),
      ITransparentUpgradeableProxyDeployer(msg.sender).paramAdmin(),
      ITransparentUpgradeableProxyDeployer(msg.sender).paramExtraData()
    )
  { }

  /**
   * @dev Calls a function from the current implementation as specified by `_data`, which should be an encoded function call.
   *
   * Requirements:
   * - Only the admin can call this function.
   *
   * Note: The proxy admin is not allowed to interact with the proxy logic through the fallback function to avoid
   * triggering some unexpected logic. This is to allow the administrator to explicitly call the proxy, please consider
   * reviewing the encoded data `_data` and the method which is called before using this.
   *
   */
  function functionDelegateCall(
    bytes memory _data
  ) public payable ifAdmin {
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
