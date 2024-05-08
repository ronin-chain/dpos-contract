// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { ConditionalImplementControl } from "../../../extensions/version-control/ConditionalImplementControl.sol";
import { ITimingInfo } from "../../../interfaces/validator/info-fragments/ITimingInfo.sol";
import { ICoinbaseExecution } from "../../../interfaces/validator/ICoinbaseExecution.sol";
import { TransparentUpgradeableProxyV2 } from "../../../extensions/TransparentUpgradeableProxyV2.sol";
import { ContractType } from "../../../utils/ContractType.sol";

/**
 * @title RoninValidatorSetREP10Migrator
 * @dev A contract that supports migration for RoninValidatorSet to REP-10.
 *
 * Action:             |                            proposal executed              wrap up period       wrap up activated period             |
 *                     |                                  v                              v                       v                           |
 *                     |----------------------------------*------------------------------*-----------------------*--*------------------------|
 *                     |                                  |                              |                       ^                           |
 *                     |                                  |                              |           end of period  ^                        |   
 *                     |                                  |                              |                       | first epoch of             |
 *                     |                                  |                              |                       | ACTIVATED_AT_PERIOD       |
 * Proxy:              |                                  |                              |                       |                           |
 * └─→ delegatecall    |                                  |                              |                       |                           |
 * Logic:          └─→ |       Prev Implementation        |                              |                       |                           |
 *                     |                                  └─→ upgrade                    |                       |                           |
 *                     |                                  |                       REP-10 Migrator                |                           |
 *                     |                                  |                              |                       |                           |
 *                     |                                  └─→ delegatecall               |                       |                           |
 *                     |                                  |                     Prev Implementation              |                           |
 *                     |                                  |                              |                       └─→ upgrade                 |
 *                     |                                  |                              |                       └─→ delegatecall            |
 *                     |                                  |                              |                       |     New Implementation    |
 */
contract RoninValidatorSetREP10Migrator is ConditionalImplementControl {
  /// @dev The period when the new implementation was activated.
  uint256 public immutable ACTIVATED_AT_PERIOD;

  /**
   * @dev Modifier that executes the function when conditions are met.
   * Peek to see if current period will changed and msg.sig is {ICoinbaseExecution.wrapUpEpoch} and next period is greater than or equal to {ACTIVATED_AT_PERIOD}.
   * If true, self call upgrade the contract to the new implementation.
   */
  modifier whenConditionsAreMet() override {
    if (_isConditionMet()) this.selfUpgrade();
    _;
  }

  /**
   * @dev Constructs the {RoninValidatorSetREP10Migrator} contract.
   * @param proxyStorage The address of the proxy storage contract.
   * @param prevImpl The address of the current contract implementation.
   * @param newImpl The address of the new contract implementation.
   * @param activatedAtPeriod The period when the new implementation was activated.
   */
  constructor(
    address proxyStorage,
    address prevImpl,
    address newImpl,
    uint256 activatedAtPeriod
  ) ConditionalImplementControl(proxyStorage, prevImpl, newImpl) {
    ACTIVATED_AT_PERIOD = activatedAtPeriod;
  }

  /**
   * @dev Initializes the contract with @openzepppelin-v0.5.2-Initializable.
   * This function is called while deploying middle layer migrator and {_initialized} slot is customized.
   * @param randomBeacon The address of the RandomBeacon contract.
   */
  function initialize(address randomBeacon) external initializer {
    _setContract(ContractType.RANDOM_BEACON, randomBeacon);
  }

  function selfUpgrade() external override onlyDelegateFromProxyStorage onlySelfCall {
    _upgradeTo(NEW_IMPL);
  }

  /**
   * @dev See {ConditionalImplementControl-_isConditionMet}.
   * Peak to see if the current period will be changed and the next period is ≥ {ACTIVATED_AT_PERIOD}, return true.
   * {_getConditionedImplementation} will return {NEW_IMPL}.
   * Call will be forwarded to {NEW_IMPL}.
   */
  function _isConditionMet() internal view virtual override returns (bool) {
    if (msg.sig != ICoinbaseExecution.wrapUpEpoch.selector) return false;
    return _isPeriodEnding() && _getCurrentPeriod() + 1 >= ACTIVATED_AT_PERIOD;
  }

  /**
   * @dev Internal function to get the current period from ITimingInfo.
   * @return The current period.
   */
  function _getCurrentPeriod() private view returns (uint256) {
    return ITimingInfo(address(this)).currentPeriod();
  }

  /**
   * @dev Internal function to check if the period is ending.
   * @return True if the period is ending.
   */
  function _isPeriodEnding() private view returns (bool) {
    return ITimingInfo(address(this)).isPeriodEnding();
  }

  /**
   * @dev See {ConditionalImplementControl-_requireSelfCall}.
   */
  function _requireSelfCall() internal view override {
    ConditionalImplementControl._requireSelfCall();
  }
}
