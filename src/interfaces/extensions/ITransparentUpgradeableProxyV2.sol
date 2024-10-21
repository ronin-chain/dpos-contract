// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITransparentUpgradeableProxyV2 {
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
  ) external payable;
}
