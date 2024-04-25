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
  /**
   * @dev Modifier that executes the function when conditions are met.
   * If the function is {wrapUpEpoch} from {ICoinbaseExecution},
   * it checks the current period before and after execution.
   * If they differ, it triggers the {selfUpgrade} function.
   */
  modifier whenConditionsAreMet() override {
    if (msg.sig == ICoinbaseExecution.wrapUpEpoch.selector) {
      uint256 currentPeriod = _getCurrentPeriod();
      _;
      if (currentPeriod != _getCurrentPeriod()) {
        this.selfUpgrade();
      }
    } else {
      _;
    }
  }

  /**
   * @dev Constructs the {RoninValidatorSetREP10Migrator} contract.
   * @param proxyStorage The address of the proxy storage contract.
   * @param prevImpl The address of the current contract implementation.
   * @param newImpl The address of the new contract implementation.
   */
  constructor(
    address proxyStorage,
    address prevImpl,
    address newImpl
  ) ConditionalImplementControl(proxyStorage, prevImpl, newImpl) { }

  /**
   * @dev Initializes the contract with @openzepppelin-v0.5.2-Initializable.
   * @notice This function is called while deploying middle layer migrator and {_initialized} slot is customized.
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

  function _requireSelfCall() internal view override {
    ConditionalImplementControl._requireSelfCall();
  }
}
