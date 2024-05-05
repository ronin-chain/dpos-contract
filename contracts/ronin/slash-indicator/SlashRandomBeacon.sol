// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { HasContracts } from "../../extensions/collections/HasContracts.sol";
import { IRoninValidatorSet } from "../../interfaces/validator/IRoninValidatorSet.sol";
import { ITimingInfo } from "../../interfaces/validator/info-fragments/ITimingInfo.sol";
import { ISlashRandomBeacon } from "../../interfaces/slash-indicator/ISlashRandomBeacon.sol";
import { ContractType } from "../../utils/ContractType.sol";

abstract contract SlashRandomBeacon is ISlashRandomBeacon, HasContracts {
  /// @dev value is equal to keccak256(abi.encode(uint256(keccak256("@ronin.SlashRandomBeacon.storage.SlashRandomBeaconConfig")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant $$_SlashRandomBeaconConfigStorageLocation =
    0x91c8f2da0132d5a54177c69679e2999120ba8f9ed42cabc35c99b69642ac8500;

  /**
   * @inheritdoc ISlashRandomBeacon
   */
  function slashRandomBeacon(address validatorId, uint256 period) external onlyContract(ContractType.RANDOM_BEACON) {
    IRoninValidatorSet validatorContract = IRoninValidatorSet(getContract(ContractType.VALIDATOR));
    SlashRandomBeaconConfig memory config = _getSlashRandomBeaconConfig();
    uint256 currPeriod = ITimingInfo(address(validatorContract)).currentPeriod();

    if (currPeriod < config._activatedAtPeriod) return;

    emit Slashed(validatorId, SlashType.RANDOM_BEACON, period);

    validatorContract.execSlash({
      cid: validatorId,
      newJailedUntil: 0,
      slashAmount: config._slashAmount,
      cannotBailout: false
    });
  }

  /**
   * @inheritdoc ISlashRandomBeacon
   */
  function getRandomBeaconSlashingConfigs() external pure returns (SlashRandomBeaconConfig memory config) {
    return _getSlashRandomBeaconConfig();
  }

  /**
   * @inheritdoc ISlashRandomBeacon
   */
  function setRandomBeaconSlashingConfigs(uint256 slashAmount, uint256 activatedAtPeriod) external onlyAdmin {
    _setRandomBeaconSlashingConfigs(slashAmount, activatedAtPeriod);
  }

  /**
   * @dev See `ISlashRandomBeacon-setRandomBeaconSlashingConfigs`.
   */
  function _setRandomBeaconSlashingConfigs(uint256 slashAmount, uint256 activatedAtPeriod) internal {
    SlashRandomBeaconConfig storage $ = _getSlashRandomBeaconConfig();

    $._slashAmount = slashAmount;
    $._activatedAtPeriod = activatedAtPeriod;

    emit RandomBeaconSlashingConfigsUpdated(slashAmount);
  }

  /**
   * @dev Returns the storage of the random beacon slashing configs.
   */
  function _getSlashRandomBeaconConfig() private pure returns (SlashRandomBeaconConfig storage $) {
    assembly ("memory-safe") {
      $.slot := $$_SlashRandomBeaconConfigStorageLocation
    }
  }
}
