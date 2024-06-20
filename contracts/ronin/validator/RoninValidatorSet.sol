// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../interfaces/validator/IRoninValidatorSet.sol";
import "./CoinbaseExecution.sol";
import "./SlashingExecution.sol";

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
  function __css2cid(TConsensus consensusAddr) internal view override(EmergencyExit, CommonStorage) returns (address) {
    return IProfile(getContract(ContractType.PROFILE)).getConsensus2Id(consensusAddr);
  }

  /**
   * @dev Convert many consensus addresses to corresponding ids from the Profile contract.
   */
  function __css2cidBatch(TConsensus[] memory consensusAddrs)
    internal
    view
    override(EmergencyExit, CommonStorage)
    returns (address[] memory)
  {
    return IProfile(getContract(ContractType.PROFILE)).getManyConsensus2Id(consensusAddrs);
  }

  /**
   * @dev Convert many id to corresponding consensus addresses from the Profile contract.
   */
  function __cid2cssBatch(address[] memory cids)
    internal
    view
    override(EmergencyExit, ValidatorInfoStorageV2)
    returns (TConsensus[] memory)
  {
    return IProfile(getContract(ContractType.PROFILE)).getManyId2Consensus(cids);
  }
}
