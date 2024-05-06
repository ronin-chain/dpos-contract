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
 */
contract RoninValidatorSetREP10Migrator is ConditionalImplementControl {
  /// @dev The period when the new implementation was activated.
  uint256 public immutable ACTIVATED_AT_PERIOD;

  /**
   * @dev Modifier that executes the function when conditions are met.
   * If the function is {wrapUpEpoch} from {ICoinbaseExecution},
   * Check if the current period is greater than or equal to {ACTIVATED_AT_PERIOD}.
   * If true, self call upgrade the contract to the new implementation.
   */
  modifier whenConditionsAreMet() override {
    _;

    if (msg.sig == ICoinbaseExecution.wrapUpEpoch.selector && _getCurrentPeriod() >= ACTIVATED_AT_PERIOD) {
      this.selfUpgrade();
    }
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
   * @dev Internal function to choose the current version of the contract implementation.
   * @return The address of the current version implementation.
   */
  function _getConditionedImplementation() internal view override returns (address) {
    return PREV_IMPL;
  }

  /**
   * @dev Internal function to get the current period from ITimingInfo.
   * @return The current period.
   */
  function _getCurrentPeriod() private view returns (uint256) {
    return ITimingInfo(address(this)).currentPeriod();
  }

  /**
   * @dev See {ConditionalImplementControl-_requireSelfCall}.
   */
  function _requireSelfCall() internal view override {
    ConditionalImplementControl._requireSelfCall();
  }
}
