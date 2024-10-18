// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StdStyle } from "forge-std/StdStyle.sol";
import { console } from "forge-std/console.sol";

import { LibErrorHandler } from "@fdk/libraries/LibErrorHandler.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { BaseMigration } from "@fdk/BaseMigration.s.sol";
import { Contract } from "../utils/Contract.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin-v4/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IAccessControl } from "@openzeppelin-v4/contracts/access/IAccessControl.sol";
import { TContract } from "@fdk/types/TContract.sol";
import { ICandidateManager } from "src/interfaces/validator/ICandidateManager.sol";
import { ICandidateStaking } from "src/interfaces/staking/ICandidateStaking.sol";
import { IStaking } from "src/interfaces/staking/IStaking.sol";
import { IRoninTrustedOrganization } from "src/interfaces/IRoninTrustedOrganization.sol";
import { IRoninValidatorSet } from "src/interfaces/validator/IRoninValidatorSet.sol";
import { Proposal } from "src/libraries/Proposal.sol";
import { RoninGovernanceAdmin } from "src/ronin/RoninGovernanceAdmin.sol";

import "./PostChecker_Helper.sol";
import { vme } from "@fdk/utils/Constants.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";

abstract contract PostChecker_GovernanceAdmin is BaseMigration, PostChecker_Helper {
  using LibProxy for *;
  using LibErrorHandler for bool;

  bytes32 private constant DEFAULT_ADMIN_ROLE = 0x00;

  // @dev Array to store all proxy targets that share same proxy admin
  address[] private _proxyTargets;

  /// @dev Array to store all proxy targets with access control
  address[] private _proxyACTargets;

  address payable private __governanceAdmin;
  address private __trustedOrg;
  RoninGovernanceAdmin private __newGovernanceAdmin;

  modifier cleanUpProxyTargets() {
    _;
    delete _proxyTargets;
    delete _proxyACTargets;
  }

  function _postCheck__GovernanceAdmin() internal {
    __governanceAdmin = loadContract(Contract.RoninGovernanceAdmin.key());
    __trustedOrg = loadContract(Contract.RoninTrustedOrganization.key());

    _postCheck__UpgradeAllContracts();
    _postCheck__ChangeAdminAllContracts();
  }

  function _postCheck__UpgradeAllContracts()
    private
    cleanUpProxyTargets
    logPostCheck("[GovernanceAdmin] upgrade all contracts")
  {
    // Get all contracts deployed from the current network
    address payable[] memory addrs = vme.getAllAddresses(network());

    // Identify proxy targets to upgrade with proposal
    for (uint256 i; i < addrs.length; ++i) {
      try this.getProxyAdmin(addrs[i]) returns (address payable proxy) {
        if (proxy == __governanceAdmin) {
          console.log("Target Proxy to test upgrade with proposal", vm.getLabel(addrs[i]));
          _proxyTargets.push(addrs[i]);
        }
      } catch { }
    }

    address[] memory targets = _proxyTargets;
    for (uint256 i; i < targets.length; ++i) {
      TContract contractType = vme.getContractTypeFromCurrentNetwork(targets[i]);
      console.log("Upgrading contract:", vm.getLabel(targets[i]));
      _upgradeProxy(contractType);
    }
  }

  function _postCheck__ChangeAdminAllContracts()
    private
    cleanUpProxyTargets
    logPostCheck("[GovernanceAdmin] change admin all contracts")
  {
    __newGovernanceAdmin =
      new RoninGovernanceAdmin(block.chainid, __trustedOrg, loadContract(Contract.RoninValidatorSet.key()), 14 days);

    // Get all contracts deployed from the current network
    address payable[] memory addrs = vme.getAllAddresses(network());

    // Identify proxy targets to change admin
    for (uint256 i; i < addrs.length; ++i) {
      try this.getProxyAdmin(addrs[i]) returns (address payable adminOfProxy) {
        if (adminOfProxy != __governanceAdmin) {
          console.log(
            string.concat(
              StdStyle.yellow(unicode"⚠️ [WARNING] "),
              "Contract ",
              vm.getLabel(addrs[i]),
              "has different admin: ",
              vm.toString(adminOfProxy)
            )
          );

          continue;
        }

        console.log("Target Proxy to change admin with proposal:", vm.getLabel(addrs[i]));
        _proxyTargets.push(addrs[i]);

        // Change default admin role if it exist in the proxy
        (bool success, bytes memory returnData) =
          addrs[i].call(abi.encodeCall(IAccessControl.hasRole, (DEFAULT_ADMIN_ROLE, __governanceAdmin)));

        if (success && abi.decode(returnData, (bool))) {
          console.log("Target Proxy to change default admin role:", vm.getLabel(addrs[i]));
          _proxyACTargets.push(addrs[i]);
        }
      } catch { }
    }

    {
      uint256 innerCallCount = _proxyTargets.length + _proxyACTargets.length * 2;
      address[] memory targets = new address[](innerCallCount);
      uint256[] memory values = new uint256[](innerCallCount);
      bytes[] memory callDatas = new bytes[](innerCallCount);

      // Build `changeAdmin` calldata to migrate to new Ronin Governance Admin
      for (uint256 i; i < _proxyTargets.length; ++i) {
        targets[i] = _proxyTargets[i];
        callDatas[i] =
          abi.encodeWithSelector(TransparentUpgradeableProxy.changeAdmin.selector, address(__newGovernanceAdmin));
      }

      for (uint i; i < _proxyACTargets.length; ++i) {
        uint j = _proxyTargets.length + i;
        targets[j] = _proxyACTargets[i];
        callDatas[j] = abi.encodeCall(IAccessControl.grantRole, (DEFAULT_ADMIN_ROLE, address(__newGovernanceAdmin)));

        targets[j + 1] = _proxyACTargets[i];
        callDatas[j + 1] = abi.encodeCall(IAccessControl.renounceRole, (DEFAULT_ADMIN_ROLE, address(__governanceAdmin)));
      }

      Proposal.ProposalDetail memory proposal = LibProposal.buildProposal(
        RoninGovernanceAdmin(__governanceAdmin), vm.getBlockTimestamp() + 5 minutes, targets, values, callDatas
      );

      // // Execute the proposal
      LibProposal.executeProposal(
        RoninGovernanceAdmin(__governanceAdmin), IRoninTrustedOrganization(__trustedOrg), proposal
      );
      delete _proxyTargets;
      delete _proxyACTargets;
    }

    // Change broken Ronin Governance Admin to new Ronin Governance Admin
    vme.setAddress(network(), Contract.RoninGovernanceAdmin.key(), address(__newGovernanceAdmin));
  }

  function getProxyAdmin(address payable proxy) external view returns (address payable proxyAdmin) {
    return proxy.getProxyAdmin();
  }
}
