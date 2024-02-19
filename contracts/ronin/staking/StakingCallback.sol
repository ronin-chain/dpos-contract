// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../../interfaces/IProfile.sol";
import "../../interfaces/staking/IStakingCallback.sol";
import "./CandidateStaking.sol";
import "./DelegatorStaking.sol";

abstract contract StakingCallback is CandidateStaking, DelegatorStaking, IStakingCallback {
  /**
   * @dev Requirements:
   * - Only Profile contract can call this method.
   */
  function execChangeAdminAddress(
    address poolId,
    address currAdminAddr,
    address newAdminAddr
  ) external override onlyContract(ContractType.PROFILE) {
    PoolDetail storage _pool = _poolDetail[poolId];

    _pool.wasAdmin[newAdminAddr] = true;
    _changeStakeholder({ _pool: _pool, requester: currAdminAddr, newStakeholder: newAdminAddr });

    _adminOfActivePoolMapping[_pool.__shadowedPoolAdmin] = address(0);
    _pool.__shadowedPoolAdmin = newAdminAddr;

    _adminOfActivePoolMapping[newAdminAddr] = poolId;
  }
}
