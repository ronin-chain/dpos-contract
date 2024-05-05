// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { IBaseSlash } from "./IBaseSlash.sol";

interface ISlashRandomBeacon is IBaseSlash {
  struct SlashRandomBeaconConfig {
    uint256 _slashAmount;
    uint256 _activatedAtPeriod;
  }

  /**
   * @dev Emitted when the configs to slash random beacon is updated. See the method `getRandomBeaconSlashingConfigs`
   * for param details.
   */
  event RandomBeaconSlashingConfigsUpdated(uint256 slashRandomBeaconAmount);

  /**
   * @dev Slashes for random beacon.
   *
   * Requirements:
   * - Only RandomBeacon contract is allowed to call.
   *
   * Emits the event `Slashed`.
   *
   * @param validatorId The id of the validator.
   * @param period The current period.
   */
  function slashRandomBeacon(address validatorId, uint256 period) external;

  /**
   * @dev Returns the configs related to block producer slashing.
   *
   * @return config The random beacon slash configs.
   *
   */
  function getRandomBeaconSlashingConfigs() external view returns (SlashRandomBeaconConfig memory config);

  /**
   * @dev Sets the configs to slash block producers.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the event `RandomBeaconSlashingConfigsUpdated`.
   *
   * @param slashAmount The amount of RON to slash random beacon.
   * @param activatedAtPeriod The period to activate the slashing.
   */
  function setRandomBeaconSlashingConfigs(uint256 slashAmount, uint256 activatedAtPeriod) external;
}
