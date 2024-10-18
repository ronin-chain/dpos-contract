// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { IProfile } from "../../interfaces/IProfile.sol";
import { IRoninValidatorSet } from "../../interfaces/validator/IRoninValidatorSet.sol";
import { ITimingInfo } from "../../interfaces/validator/info-fragments/ITimingInfo.sol";
import { EmergencyExit } from "../../ronin/validator/EmergencyExit.sol";
import { CommonStorage } from "../../ronin/validator/storage-fragments/CommonStorage.sol";
import { TConsensus } from "../../udvts/Types.sol";
import { ContractType } from "../../utils/ContractType.sol";
import { CoinbaseExecution } from "./CoinbaseExecution.sol";
import { SlashingExecution } from "./SlashingExecution.sol";
import { TimingStorage } from "./storage-fragments/TimingStorage.sol";
import { ValidatorInfoStorageV2 } from "./storage-fragments/ValidatorInfoStorageV2.sol";
import { Initializable } from "@openzeppelin-v4/contracts/proxy/utils/Initializable.sol";

contract RoninValidatorSet is Initializable, CoinbaseExecution, SlashingExecution {
  constructor() {
    _disableInitializers();
  }

  fallback() external payable {
    _fallback();
  }

  receive() external payable {
    _fallback();
  }

  /**
   * @dev Only receives RON from staking vesting contract (for topping up bonus), and from staking contract (for transferring
   * deducting amount on slashing).
   */
  function _fallback() internal view {
    if (msg.sender != getContract(ContractType.STAKING_VESTING) && msg.sender != getContract(ContractType.STAKING)) {
      revert ErrUnauthorizedReceiveRON();
    }
  }

  /**
   * @dev Convert consensus address to corresponding id from the Profile contract.
   */
  function __css2cid(
    TConsensus consensusAddr
  ) internal view override(EmergencyExit, CommonStorage) returns (address) {
    return IProfile(getContract(ContractType.PROFILE)).getConsensus2Id(consensusAddr);
  }

  /**
   * @dev Convert many consensus addresses to corresponding ids from the Profile contract.
   */
  function __css2cidBatch(
    TConsensus[] memory consensusAddrs
  ) internal view override(EmergencyExit, CommonStorage) returns (address[] memory) {
    return IProfile(getContract(ContractType.PROFILE)).getManyConsensus2Id(consensusAddrs);
  }

  /**
   * @dev Convert many id to corresponding consensus addresses from the Profile contract.
   */
  function __cid2cssBatch(
    address[] memory cids
  ) internal view override(EmergencyExit, ValidatorInfoStorageV2) returns (TConsensus[] memory) {
    return IProfile(getContract(ContractType.PROFILE)).getManyId2Consensus(cids);
  }
}
