// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ConditionalImplementControl } from "../../../extensions/version-control/ConditionalImplementControl.sol";
import { ITimingInfo } from "../../../interfaces/validator/info-fragments/ITimingInfo.sol";
import { ICoinbaseExecution } from "../../../interfaces/validator/ICoinbaseExecution.sol";
import { ContractType } from "../../../utils/ContractType.sol";
import { ErrorHandler } from "../../../libraries/ErrorHandler.sol";

/**
 * @title RoninValidatorSetTimedMigrator
 * @dev A contract that facilitates timed migration of the Ronin validator set using conditional version control.
 */
contract RoninValidatorSetTimedMigrator is ConditionalImplementControl {
  using ErrorHandler for bool;

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
   * @dev Constructs the {RoninValidatorSetTimedMigrator} contract.
   * @param proxyStorage The address of the proxy storage contract.
   * @param prevImpl The address of the current contract implementation.
   * @param newImpl The address of the new contract implementation.
   */
  constructor(
    address proxyStorage,
    address prevImpl,
    address newImpl
  ) ConditionalImplementControl(proxyStorage, prevImpl, newImpl) { }

  function initialize(bytes[] calldata callDatas) external initializer {
    uint256 length = callDatas.length;
    bool success;
    bytes memory returnOrRevertData;

    for (uint256 i = 0; i < length; i++) {
      (success, returnOrRevertData) = NEW_IMPL.delegatecall(callDatas[i]);
      success.handleRevert(bytes4(callDatas[i][:4]), returnOrRevertData);
    }
  }

  function selfUpgrade() external override onlyDelegateFromProxyStorage onlySelfCall {
    _upgradeTo(NEW_IMPL);

    ConditionalImplementControl(getContract(ContractType.STAKING)).selfUpgrade();
    ConditionalImplementControl(getContract(ContractType.SLASH_INDICATOR)).selfUpgrade();
    ConditionalImplementControl(getContract(ContractType.BRIDGE_TRACKING)).selfUpgrade();
    ConditionalImplementControl(getContract(ContractType.RONIN_TRUSTED_ORGANIZATION)).selfUpgrade();
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
