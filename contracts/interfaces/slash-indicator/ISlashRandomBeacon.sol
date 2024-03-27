// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { IBaseSlash } from "./IBaseSlash.sol";
import { TConsensus } from "../../udvts/Types.sol";

interface ISlashRandomBeacon is IBaseSlash {
  /**
   * @dev Emitted when the configs to slash random beacon is updated. See the method `getRandomBeaconSlashingConfigs`
   * for param details.
   */
  event RandomBeaconSlashingConfigsUpdated(uint256 slashRandomBeaconAmount);

  /**
   * @dev Slashes for random beacon.
   * @param validatorId The id of the validator.
   * @param period The current period.
   * @return slashed True if the validator is slashed successfully.
   *
   * Requirements:
   * - Only RandomBeacon contract is allowed to call.
   *
   * Emits the event `Slashed`.
   */
  function slashRandomBeacon(address validatorId, uint256 period) external returns (bool slashed);

  /**
   * @dev Returns the configs related to block producer slashing.
   *
   * @return slashRandomBeaconAmount The amount of RON to slash random beacon.
   *
   */
  function getRandomBeaconSlashingConfigs() external view returns (uint256 slashRandomBeaconAmount);

  /**
   * @dev Sets the configs to slash block producers.
   * @param slashAmount The amount of RON to slash random beacon.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the event `RandomBeaconSlashingConfigsUpdated`.
   *
   */
  function setRandomBeaconSlashingConfigs(uint256 slashAmount) external;
}
