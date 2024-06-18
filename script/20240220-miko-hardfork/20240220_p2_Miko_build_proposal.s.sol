// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TContract } from "@fdk/types/Types.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { IStaking } from "@ronin/contracts/interfaces/staking/IStaking.sol";
import { IProfile } from "@ronin/contracts/interfaces/IProfile.sol";
import { IMaintenance } from "@ronin/contracts/interfaces/IMaintenance.sol";
import { RoninGovernanceAdmin } from "@ronin/contracts/ronin/RoninGovernanceAdmin.sol";
import { IBridgeReward } from "@ronin/contracts/interfaces/bridge/IBridgeReward.sol";
import { IGovernanceAdmin } from "@ronin/contracts/interfaces/extensions/IGovernanceAdmin.sol";
import { IRoninTrustedOrganization } from "@ronin/contracts/interfaces/IRoninTrustedOrganization.sol";
import { IRoninValidatorSet } from "@ronin/contracts/interfaces/validator/IRoninValidatorSet.sol";
import { IFastFinalityTracking } from "@ronin/contracts/interfaces/IFastFinalityTracking.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { ArrayReplaceLib } from "./ArrayReplaceLib.sol";
import { Proposal__Base_20240220_MikoHardfork } from "./20240220_Base_Miko_Hardfork.s.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import { TConsensus } from "@ronin/contracts/udvts/Types.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { console } from "forge-std/console.sol";

abstract contract Proposal__20240220_MikoHardfork_BuildProposal is Proposal__Base_20240220_MikoHardfork {
  using LibProxy for *;
  using StdStyle for *;
  using ArrayReplaceLib for *;

  /**
   * See `README.md`
   */
  function _buildFinalProposal() internal returns (Proposal.ProposalDetail memory proposal) {
    address[] memory tos = new address[](40);
    bytes[] memory callDatas = new bytes[](40);
    uint256[] memory values = new uint256[](40);
    uint prCnt;

    // [B1.] Change admin of Bridge Tracking to doctor
    {
      (bytes[] memory sub_callDatas, address[] memory sub_targets, uint256[] memory sub_values) =
        _ga__changeAdminBridgeTracking();

      tos = tos.replace(sub_targets, prCnt);
      callDatas = callDatas.replace(sub_callDatas, prCnt);
      values = values.replace(sub_values, prCnt);
      prCnt += sub_callDatas.length;
    }

    // [B2.] Upgrade all contracts
    {
      (bytes[] memory sub_callDatas, address[] memory sub_targets, uint256[] memory sub_values) =
        _ga__upgradeAllDPoSContracts();

      tos = tos.replace(sub_targets, prCnt);
      callDatas = callDatas.replace(sub_callDatas, prCnt);
      values = values.replace(sub_values, prCnt);
      prCnt += sub_callDatas.length;
    }

    // [B3.] Initialize contracts
    {
      (bytes[] memory sub_callDatas, address[] memory sub_targets, uint256[] memory sub_values) = _ga__initContracts();

      tos = tos.replace(sub_targets, prCnt);
      callDatas = callDatas.replace(sub_callDatas, prCnt);
      values = values.replace(sub_values, prCnt);
      prCnt += sub_callDatas.length;
    }

    // [B4.] Replace StableNode governor
    {
      (bytes[] memory sub_callDatas, address[] memory sub_targets, uint256[] memory sub_values) =
        _ga__changeGovernorStableNode();
      tos = tos.replace(sub_targets, prCnt);
      callDatas = callDatas.replace(sub_callDatas, prCnt);
      values = values.replace(sub_values, prCnt);
      prCnt += sub_callDatas.length;
    }

    // [B5.] Change admin of all contracts
    {
      (bytes[] memory sub_callDatas, address[] memory sub_targets, uint256[] memory sub_values) =
        _ga__changeAdminAllContracts();

      tos = tos.replace(sub_targets, prCnt);
      callDatas = callDatas.replace(sub_callDatas, prCnt);
      values = values.replace(sub_values, prCnt);
      prCnt += sub_callDatas.length;
    }

    // [B5.] Change default admin role of Staking Contract
    {
      (bytes[] memory sub_callDatas, address[] memory sub_targets, uint256[] memory sub_values) =
        _ga__changeDefaultAdminRoleOfStaking();

      tos = tos.replace(sub_targets, prCnt);
      callDatas = callDatas.replace(sub_callDatas, prCnt);
      values = values.replace(sub_values, prCnt);
      prCnt += sub_callDatas.length;
    }

    // [Build proposal]
    assembly {
      mstore(tos, prCnt)
      mstore(callDatas, prCnt)
      mstore(values, prCnt)
    }

    proposal = LibProposal.buildProposal(
      roninGovernanceAdmin, vm.getBlockTimestamp() + PROPOSAL_DURATION, tos, values, callDatas
    );
  }

  function _ga__changeAdminBridgeTracking()
    internal
    returns (bytes[] memory callDatas, address[] memory targets, uint256[] memory values)
  {
    targets = new address[](2);
    callDatas = new bytes[](2);
    values = new uint256[](2);

    address doctor = ADMIN_TMP_BRIDGE_TRACKING;
    console.log("Doctor address:", doctor);
    balanceBefore = doctor.balance;
    console.log("balanceBefore", balanceBefore);

    targets[0] = address(roninGovernanceAdmin);
    callDatas[0] = abi.encodeCall(IGovernanceAdmin.changeProxyAdmin, (bridgeTracking, doctor));

    targets[1] = address(DEPRECATED_BRIDGE_REWARD);
    callDatas[1] = abi.encodeCall(IBridgeReward.initializeREP2, ());
  }

  function _ga__upgradeAllDPoSContracts()
    internal
    returns (bytes[] memory callDatas, address[] memory targets, uint256[] memory values)
  {
    address payable[] memory allContracts = allDPoSContracts;

    for (uint256 i; i < allContracts.length; ++i) {
      address proxyAdmin = allContracts[i].getProxyAdmin(false);
      if (proxyAdmin != address(roninGovernanceAdmin)) {
        console.log(
          unicode"⚠ WARNING:".yellow(),
          string.concat(
            vm.getLabel(allContracts[i]),
            " has different ProxyAdmin. Expected: ",
            vm.getLabel(address(roninGovernanceAdmin)),
            " Got: ",
            vm.toString(proxyAdmin)
          )
        );
        revert();
      } else {
        address implementation = allContracts[i].getProxyImplementation();
        TContract contractType = config.getContractTypeFromCurrentNetwork(allContracts[i]);

        if (implementation.codehash != keccak256(vm.getDeployedCode(config.getContractAbsolutePath(contractType)))) {
          console.log(
            "Different Code Hash Detected. Contract To Upgrade:".cyan(),
            vm.getLabel(allContracts[i]),
            string.concat(" Query code Hash From: ", vm.getLabel(implementation))
          );
          contractTypesToUpgrade.push(contractType);
          contractsToUpgrade.push(allContracts[i]);
        } else {
          console.log("Contract not to Upgrade:", vm.getLabel(allContracts[i]));
        }
      }
    }

    uint256 innerCallCount = contractTypesToUpgrade.length;
    console.log("Number contract to upgrade:", innerCallCount);

    callDatas = new bytes[](innerCallCount);
    targets = contractsToUpgrade;
    values = new uint256[](innerCallCount);
    address[] memory logics = new address[](innerCallCount);

    for (uint256 i; i < innerCallCount; ++i) {
      logics[i] = _deployLogic(contractTypesToUpgrade[i]);
      callDatas[i] = abi.encodeCall(TransparentUpgradeableProxy.upgradeTo, (logics[i]));

      console.log("Code hash for:", vm.getLabel(logics[i]), vm.toString(logics[i].codehash));
      console.log(
        "Computed code hash:",
        vm.toString(keccak256(vm.getDeployedCode(config.getContractAbsolutePath(contractTypesToUpgrade[i]))))
      );
    }
  }

  function _ga__initContracts()
    internal
    view
    returns (bytes[] memory callDatas, address[] memory targets, uint256[] memory values)
  {
    // See https://www.notion.so/skymavis/DPoS-Gateway-Contract-list-58e189d5feab435d9b78b04a3012155c?pvs=4#67e1c4291c834c5980a6915fc5489865
    targets = new address[](10);
    callDatas = new bytes[](10);
    values = new uint256[](10);

    targets[0] = address(maintenanceContract);
    callDatas[0] = abi.encodeCall(
      TransparentUpgradeableProxyV2.functionDelegateCall,
      abi.encodeCall(IMaintenance.initializeV3, (address(profileContract)))
    );

    targets[1] = address(validatorContract);
    callDatas[1] = abi.encodeCall(
      TransparentUpgradeableProxyV2.functionDelegateCall,
      abi.encodeCall(IRoninValidatorSet.initializeV4, (address(profileContract)))
    );

    targets[2] = address(profileContract);
    callDatas[2] = abi.encodeCall(
      TransparentUpgradeableProxyV2.functionDelegateCall,
      abi.encodeCall(IProfile.initializeV2, (address(stakingContract), address(trustedOrgContract)))
    );

    targets[3] = address(profileContract);
    callDatas[3] = abi.encodeCall(
      TransparentUpgradeableProxyV2.functionDelegateCall,
      abi.encodeCall(IProfile.initializeV3, (PROFILE_PUBKEY_CHANGE_COOLDOWN))
    );

    targets[4] = address(trustedOrgContract);
    callDatas[4] = abi.encodeCall(
      TransparentUpgradeableProxyV2.functionDelegateCall,
      abi.encodeCall(IRoninTrustedOrganization.initializeV2, (address(profileContract)))
    );

    targets[5] = address(stakingContract);
    callDatas[5] = abi.encodeCall(
      TransparentUpgradeableProxyV2.functionDelegateCall,
      abi.encodeCall(IStaking.initializeV3, (address(profileContract)))
    );

    targets[6] = address(stakingContract);
    callDatas[6] = abi.encodeCall(
      TransparentUpgradeableProxyV2.functionDelegateCall,
      abi.encodeCall(IStaking.initializeV4, (address(roninGovernanceAdmin), STAKING_MIGRATOR))
    );

    targets[7] = address(fastFinalityTrackingContract);
    callDatas[7] = abi.encodeCall(
      TransparentUpgradeableProxyV2.functionDelegateCall,
      abi.encodeCall(IFastFinalityTracking.initializeV2, (address(profileContract)))
    );

    // [C1.] The `MIGRATOR_ROLE` in the Staking will migrate the list of `wasAdmin`.
    {
      targets[8] = address(stakingContract);
      callDatas[8] = abi.encodeCall(
        TransparentUpgradeableProxyV2.functionDelegateCall,
        abi.encodeCall(IAccessControl.grantRole, (MIGRATOR_ROLE, address(roninGovernanceAdmin)))
      );

      targets[9] = address(stakingContract);
      callDatas[9] = abi.encodeCall(TransparentUpgradeableProxyV2.functionDelegateCall, _migrator__migrateWasAdmin());
    }
  }

  function _ga__changeGovernorStableNode()
    internal
    view
    returns (bytes[] memory callDatas, address[] memory targets, uint256[] memory values)
  {
    callDatas = new bytes[](2);
    targets = new address[](2);
    values = new uint256[](2);

    // Remove current governor of StableNode
    TConsensus[] memory cssList = new TConsensus[](1);
    cssList[0] = STABLE_NODE_CONSENSUS; // StableNode

    targets[0] = address(trustedOrgContract);
    callDatas[0] = abi.encodeCall(
      TransparentUpgradeableProxyV2.functionDelegateCall,
      abi.encodeCall(IRoninTrustedOrganization.removeTrustedOrganizations, (cssList))
    );

    // Add new governor for StableNode
    IRoninTrustedOrganization.TrustedOrganization[] memory trOrgLst =
      new IRoninTrustedOrganization.TrustedOrganization[](1);
    trOrgLst[0].consensusAddr = STABLE_NODE_CONSENSUS;
    trOrgLst[0].governor = STABLE_NODE_GOVERNOR;
    trOrgLst[0].weight = 100;

    targets[1] = address(trustedOrgContract);
    callDatas[1] = abi.encodeCall(
      TransparentUpgradeableProxyV2.functionDelegateCall,
      abi.encodeCall(IRoninTrustedOrganization.addTrustedOrganizations, (trOrgLst))
    );
  }

  function _migrator__migrateWasAdmin() internal view returns (bytes memory) {
    (address[] memory poolIds, address[] memory admins, bool[] memory flags) = _sys__parseMigrateData(MIGRATE_DATA_PATH);
    return abi.encodeCall(IStaking.migrateWasAdmin, (poolIds, admins, flags));
  }

  function _ga__changeAdminAllContracts()
    internal
    returns (bytes[] memory callDatas, address[] memory targets, uint256[] memory values)
  {
    address payable[] memory allContracts = allDPoSContracts;

    bool shouldPrankOnly = vme.isPostChecking();

    if (shouldPrankOnly) {
      vm.prank(DEPLOYER);
    } else {
      vm.broadcast(DEPLOYER);
    }
    _newGA =
      address(new RoninGovernanceAdmin(block.chainid, address(trustedOrgContract), address(validatorContract), 14 days));

    for (uint256 i; i < allContracts.length; ++i) {
      address proxyAdmin = allContracts[i].getProxyAdmin(false);
      // Skip if admin's of the proxy is not GA
      if (proxyAdmin != address(roninGovernanceAdmin)) {
        console.log(
          unicode"⚠ WARNING:".yellow(),
          string.concat(
            vm.getLabel(allContracts[i]),
            " has different ProxyAdmin. Expected: ",
            vm.getLabel(address(roninGovernanceAdmin)),
            " Got: ",
            vm.toString(proxyAdmin)
          )
        );
        continue;
      }

      // Change admin of the proxy
      console.log("Contract to change admin:".cyan(), vm.getLabel(allContracts[i]));
      contractsToChangeAdmin.push(allContracts[i]);

      // Change default admin role if it exist in the proxy
      (bool success, bytes memory returnData) =
        allContracts[i].call(abi.encodeCall(IAccessControl.hasRole, (DEFAULT_ADMIN_ROLE, proxyAdmin)));
      // AccessControl(allContracts[i]).hasRole(DEFAULT_ADMIN_ROLE, proxyAdmin);
      if (success && abi.decode(returnData, (bool))) {
        console.log("Contract to change default admin role:".cyan(), vm.getLabel(allContracts[i]));
        contractsToChangeDefaultAdminRole.push(allContracts[i]);
      }
    }

    uint256 innerCallCount = contractsToChangeAdmin.length + contractsToChangeDefaultAdminRole.length * 2;
    console.log("Number contract to change admin:", contractsToChangeAdmin.length);
    console.log("Number contract to change default admin role:", contractsToChangeDefaultAdminRole.length);

    callDatas = new bytes[](innerCallCount);
    targets = new address[](innerCallCount);
    values = new uint256[](innerCallCount);

    for (uint i; i < contractsToChangeAdmin.length; ++i) {
      targets[i] = contractsToChangeAdmin[i];
      callDatas[i] = abi.encodeCall(TransparentUpgradeableProxy.changeAdmin, (_newGA));
    }

    for (uint i; i < contractsToChangeDefaultAdminRole.length; ++i) {
      uint j = contractsToChangeAdmin.length + i;
      targets[j] = contractsToChangeDefaultAdminRole[i];
      callDatas[j] = abi.encodeCall(IAccessControl.grantRole, (DEFAULT_ADMIN_ROLE, _newGA));

      targets[j + 1] = contractsToChangeDefaultAdminRole[i];
      callDatas[j + 1] =
        abi.encodeCall(IAccessControl.renounceRole, (DEFAULT_ADMIN_ROLE, address(roninGovernanceAdmin)));
    }
  }

  function _ga__changeDefaultAdminRoleOfStaking()
    internal
    view
    returns (bytes[] memory callDatas, address[] memory targets, uint256[] memory values)
  {
    callDatas = new bytes[](2);
    targets = new address[](2);
    values = new uint256[](2);

    targets[0] = address(stakingContract);
    callDatas[0] = abi.encodeCall(IAccessControl.grantRole, (DEFAULT_ADMIN_ROLE, _newGA));

    targets[1] = address(stakingContract);
    callDatas[1] = abi.encodeCall(IAccessControl.renounceRole, (DEFAULT_ADMIN_ROLE, address(roninGovernanceAdmin)));
  }
}
