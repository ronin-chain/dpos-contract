// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IHasContracts } from "../collections/IHasContracts.sol";
import { IGovernanceProposal } from "./sequential-governance/IGovernanceProposal.sol";

interface IGovernanceAdmin is IGovernanceProposal, IHasContracts {
  function DOMAIN_SEPARATOR() external view returns (bytes32);

  /**
   * @dev Changes the admin of `proxy` to `newAdmin`.
   *
   * Requirements:
   * - This contract must be the current admin of `proxy`.
   *
   */
  function changeProxyAdmin(address proxy, address newAdmin) external;

  /**
   * @dev Returns the proposal expiry duration.
   */
  function getProposalExpiryDuration() external view returns (uint256);

  /**
   * @dev Returns the current admin of `proxy`.
   *
   * Requirements:
   * - This contract must be the admin of `proxy`.
   *
   */
  function getProxyAdmin(
    address proxy
  ) external view returns (address);

  /**
   * @dev Returns the current implementation of `_proxy`.
   *
   * Requirements:
   * - This contract must be the admin of `_proxy`.
   *
   */
  function getProxyImplementation(
    address proxy
  ) external view returns (address);

  function roninChainId() external view returns (uint256);

  function setProposalExpiryDuration(
    uint256 _expiryDuration
  ) external;
}
