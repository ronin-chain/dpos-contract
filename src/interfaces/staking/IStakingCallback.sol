// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { TPoolId } from "../../udvts/Types.sol";

interface IStakingCallback {
  /**
   * @dev Requirements:
   * - Only Profile contract can call this method.
   */
  function execChangeAdminAddr(address poolId, address currAdminAddr, address newAdminAddr) external;
}
