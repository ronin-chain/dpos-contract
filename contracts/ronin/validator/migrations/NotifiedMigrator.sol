// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ConditionalImplementControl } from "../../../extensions/version-control/ConditionalImplementControl.sol";
import { ErrUnauthorizedCall } from "../../../utils/CommonErrors.sol";
import { ErrorHandler } from "../../../libraries/ErrorHandler.sol";

contract NotifiedMigrator is ConditionalImplementControl {
  using ErrorHandler for bool;

  address public immutable NOTIFIER;

  constructor(
    address proxyStorage,
    address prevImpl,
    address newImpl,
    address notifier
  ) payable ConditionalImplementControl(proxyStorage, prevImpl, newImpl) {
    NOTIFIER = notifier;
  }

  function initialize(
    bytes[] calldata callDatas
  ) external initializer {
    uint256 length = callDatas.length;
    bool success;
    bytes memory returnOrRevertData;

    for (uint256 i = 0; i < length; i++) {
      (success, returnOrRevertData) = NEW_IMPL.delegatecall(callDatas[i]);
      success.handleRevert(bytes4(callDatas[i][:4]), returnOrRevertData);
    }
  }

  /**
   * @dev See {IConditionalImplementControl-selfUpgrade}.
   */
  function selfUpgrade() external override onlyDelegateFromProxyStorage {
    if (msg.sender != NOTIFIER) revert ErrUnauthorizedCall(msg.sig);
    _upgradeTo(NEW_IMPL);
  }
}
