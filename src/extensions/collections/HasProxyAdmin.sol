// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../utils/CommonErrors.sol";
import "@openzeppelin-v4/contracts/utils/StorageSlot.sol";

abstract contract HasProxyAdmin {
  // bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1));
  bytes32 private constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

  modifier onlyAdmin() {
    _requireAdmin();
    _;
  }

  /**
   * @dev Returns proxy admin.
   */
  function _getAdmin() internal view virtual returns (address) {
    return StorageSlot.getAddressSlot(_ADMIN_SLOT).value;
  }

  function _requireAdmin() internal view {
    if (msg.sender != _getAdmin()) revert ErrUnauthorized(msg.sig, RoleAccess.ADMIN);
  }
}
