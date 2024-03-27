// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { HasContracts } from "../../extensions/collections/HasContracts.sol";
import { IRoninValidatorSet } from "../../interfaces/validator/IRoninValidatorSet.sol";
import { ISlashRandomBeacon } from "../../interfaces/slash-indicator/ISlashRandomBeacon.sol";
import { ContractType } from "../../utils/ContractType.sol";

abstract contract SlashRandomBeacon is ISlashRandomBeacon, HasContracts {
  /// @dev The amount of RON to slash random beacon.
  uint256 internal _slashRandomBeaconAmount;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[19] private ______gap;

  /**
   * @inheritdoc ISlashRandomBeacon
   */
  function slashRandomBeacon(
    address validatorId,
    uint256 period
  ) external onlyContract(ContractType.RANDOM_BEACON) returns (bool slashed) {
    IRoninValidatorSet validatorContract = IRoninValidatorSet(getContract(ContractType.VALIDATOR));
    emit Slashed(validatorId, SlashType.RANDOM_BEACON, period);

    slashed = validatorContract.execSlash({
      cid: validatorId,
      newJailedUntil: 0,
      slashAmount: _slashRandomBeaconAmount,
      cannotBailout: true
    });
  }

  /**
   * @inheritdoc ISlashRandomBeacon
   */
  function getRandomBeaconSlashingConfigs() external view returns (uint256 slashRandomBeaconAmount) {
    return _slashRandomBeaconAmount;
  }

  /**
   * @inheritdoc ISlashRandomBeacon
   */
  function setRandomBeaconSlashingConfigs(uint256 slashAmount) external onlyAdmin {
    _setRandomBeaconSlashingConfigs(slashAmount);
  }

  /**
   * @dev See `ISlashRandomBeacon-setRandomBeaconSlashingConfigs`.
   */
  function _setRandomBeaconSlashingConfigs(uint256 slashAmount) internal {
    _slashRandomBeaconAmount = slashAmount;
    emit RandomBeaconSlashingConfigsUpdated(slashAmount);
  }
}
