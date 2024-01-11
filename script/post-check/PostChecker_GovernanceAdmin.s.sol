// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StdStyle } from "forge-std/StdStyle.sol";
import { console2 as console } from "forge-std/console2.sol";

import { LibErrorHandler } from "contract-libs/LibErrorHandler.sol";
import { TContract } from "foundry-deployment-kit/types/Types.sol";
import { LibProxy } from "foundry-deployment-kit/libraries/LibProxy.sol";
import { BaseMigration } from "foundry-deployment-kit/BaseMigration.s.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { ICandidateManager } from "@ronin/contracts/interfaces/validator/ICandidateManager.sol";
import { ICandidateStaking } from "@ronin/contracts/interfaces/staking/ICandidateStaking.sol";
import { IStaking } from "@ronin/contracts/interfaces/staking/IStaking.sol";
import { RoninValidatorSet } from "@ronin/contracts/ronin/validator/RoninValidatorSet.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";

import { RoninGovernanceAdmin } from "@ronin/contracts/ronin/RoninGovernanceAdmin.sol";
import { RoninTrustedOrganization } from "@ronin/contracts/multi-chains/RoninTrustedOrganization.sol";

import "./PostChecker_Helper.sol";

abstract contract PostChecker_GovernanceAdmin is BaseMigration, PostChecker_Helper {
  using LibProxy for *;
  using LibErrorHandler for bool;

  // @dev Array to store all proxy targets that share same proxy admin
  address[] private _proxyTargets;

  address payable private __governanceAdmin;
  address private __trustedOrg;
  RoninGovernanceAdmin private __newGovernanceAdmin;

  modifier cleanUpProxyTargets() {
    _;
    delete _proxyTargets;
  }

  function _postCheck__GovernanceAdmin() internal {
    __governanceAdmin = CONFIG.getAddressFromCurrentNetwork(Contract.RoninGovernanceAdmin.key());
    __trustedOrg = CONFIG.getAddressFromCurrentNetwork(Contract.RoninTrustedOrganization.key());

    _postCheck__UpgradeAllContracts();
    _postCheck__ChangeAdminAllContracts();
  }

  function _postCheck__UpgradeAllContracts()
    private
    cleanUpProxyTargets
    logPostCheck("[GovernanceAdmin] upgrade all contracts")
  {
    // Get all contracts deployed from the current network
    address payable[] memory addrs = CONFIG.getAllAddresses(network());

    // Identify proxy targets to upgrade with proposal
    for (uint256 i; i < addrs.length; ++i) {
      try this.getProxyAdmin(addrs[i]) returns (address payable proxy) {
        if (proxy == __governanceAdmin) {
          console.log("Target Proxy to test upgrade with proposal", vm.getLabel(addrs[i]));
          _proxyTargets.push(addrs[i]);
        }
      } catch {}
    }

    address[] memory targets = _proxyTargets;
    for (uint256 i; i < targets.length; ++i) {
      TContract contractType = CONFIG.getContractTypeFromCurrentNetwok(targets[i]);
      console.log("Upgrading contract:", vm.getLabel(targets[i]));
      _upgradeProxy(contractType);
    }
  }

  function _postCheck__ChangeAdminAllContracts()
    private
    cleanUpProxyTargets
    logPostCheck("[GovernanceAdmin] change admin all contracts")
  {
    ISharedArgument.SharedParameter memory param = ISharedArgument(address(CONFIG)).sharedArguments();

    __newGovernanceAdmin = new RoninGovernanceAdmin(
      block.chainid,
      __trustedOrg,
      CONFIG.getAddressFromCurrentNetwork(Contract.RoninValidatorSet.key()),
      param.expiryDuration
    );

    // Get all contracts deployed from the current network
    address payable[] memory addrs = CONFIG.getAllAddresses(network());

    // Identify proxy targets to change admin
    for (uint256 i; i < addrs.length; ++i) {
      try this.getProxyAdmin(addrs[i]) returns (address payable adminOfProxy) {
        if (adminOfProxy == __governanceAdmin) {
          console.log("Target Proxy to change admin with proposal", vm.getLabel(addrs[i]));
          _proxyTargets.push(addrs[i]);
        } else {
          console.log(
            string.concat(
              StdStyle.yellow(unicode"⚠️ [WARNING] "),
              "Contract ",
              vm.getLabel(addrs[i]),
              "has different admin: ",
              vm.toString(adminOfProxy)
            )
          );
        }
      } catch {}
    }

    {
      address[] memory targets = _proxyTargets;
      uint256[] memory values = new uint256[](targets.length);
      bytes[] memory callDatas = new bytes[](targets.length);

      // Build `changeAdmin` calldata to migrate to new Ronin Governance Admin
      for (uint256 i; i < targets.length; ++i) {
        callDatas[i] = abi.encodeWithSelector(
          TransparentUpgradeableProxy.changeAdmin.selector,
          address(__newGovernanceAdmin)
        );
      }

      Proposal.ProposalDetail memory proposal = _buildProposal(
        RoninGovernanceAdmin(__governanceAdmin),
        block.timestamp + 5 minutes,
        targets,
        values,
        callDatas
      );

      // // Execute the proposal
      _executeProposal(RoninGovernanceAdmin(__governanceAdmin), RoninTrustedOrganization(__trustedOrg), proposal);
      delete _proxyTargets;
    }

    // Change broken Ronin Governance Admin to new Ronin Governance Admin
    CONFIG.setAddress(network(), Contract.RoninGovernanceAdmin.key(), address(__newGovernanceAdmin));
  }

  function getProxyAdmin(address payable proxy) external returns (address payable proxyAdmin) {
    return proxy.getProxyAdmin();
  }

  function _executeProposal(
    RoninGovernanceAdmin governanceAdmin,
    RoninTrustedOrganization roninTrustedOrg,
    Proposal.ProposalDetail memory proposal
  ) internal virtual;

  function _buildProposal(
    RoninGovernanceAdmin governanceAdmin,
    uint256 expiry,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory callDatas
  ) internal virtual returns (Proposal.ProposalDetail memory proposal);

  function _setDisableLogProposalStatus(bool flag) internal virtual;
}
