// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TContract } from "foundry-deployment-kit/types/Types.sol";
import { LibProxy } from "foundry-deployment-kit/libraries/LibProxy.sol";
import { StdStyle } from "forge-std/StdStyle.sol";

import { BridgeTrackingRecoveryLogic, BridgeTracking } from "../20231019-recover-fund/contracts/BridgeTrackingRecoveryLogic.sol";

import { SlashIndicator } from "@ronin/contracts/ronin/slash-indicator/SlashIndicator.sol";
import { Staking, IStaking } from "@ronin/contracts/ronin/staking/Staking.sol";
import { Profile } from "@ronin/contracts/ronin/profile/Profile.sol";
import { Maintenance } from "@ronin/contracts/ronin/Maintenance.sol";
import { RoninValidatorSet } from "@ronin/contracts/ronin/validator/RoninValidatorSet.sol";
import { StakingVesting } from "@ronin/contracts/ronin/StakingVesting.sol";
import { FastFinalityTracking } from "@ronin/contracts/ronin/fast-finality/FastFinalityTracking.sol";

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

import "./ArrayReplaceLib.sol";
import "./MikoHelper.s.sol";

contract Proposal__20240220_MikoHardfork is MikoHelper {
  using LibProxy for *;
  using StdStyle for *;
  using ArrayReplaceLib for *;

  uint256 balanceBefore;

  address internal _newGA;

  address payable[] private allDPoSContracts;
  address[] private contractsToUpgrade;
  address[] private contractsToChangeAdmin;
  TContract[] private contractTypesToUpgrade;

  RoninGovernanceAdmin private roninGovernanceAdmin;
  RoninTrustedOrganization private trustedOrgContract;

  address private bridgeTracking;
  address private roninBridgeManager;
  SlashIndicator private slashIndicatorContract;
  FastFinalityTracking private fastFinalityTrackingContract;
  Profile private profileContract;
  Staking private stakingContract;
  StakingVesting private stakingVestingContract;
  Maintenance private maintenanceContract;
  RoninValidatorSet private validatorContract;

  /**
   * See `README.md`
   */
  function run() public onlyOn(DefaultNetwork.RoninMainnet.key()) {
    address sender = sender();
    console.log("Default sender:", sender);

    _sys__loadContracts();
    _node__changeStorage();
    _eoa__changeAdminToGA();

    address[] memory tos = new address[](30);
    bytes[] memory callDatas = new bytes[](30);
    uint256[] memory values = new uint256[](30);
    uint prCnt;

    // [B1.] Change admin of Bridge Tracking to doctor
    {
      (
        bytes[] memory sub_callDatas,
        address[] memory sub_targets,
        uint256[] memory sub_values
      ) = _ga__changeAdminBridgeTracking();

      tos = tos.replace(sub_targets, prCnt);
      callDatas = callDatas.replace(sub_callDatas, prCnt);
      values = values.replace(sub_values, prCnt);
      prCnt += sub_callDatas.length;
    }

    // [B2.] Upgrade all contracts
    {
      (
        bytes[] memory sub_callDatas,
        address[] memory sub_targets,
        uint256[] memory sub_values
      ) = _ga__upgradeAllDPoSContracts();

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

    // [B4.] Change admin of all contracts
    {
      (
        bytes[] memory sub_callDatas,
        address[] memory sub_targets,
        uint256[] memory sub_values
      ) = _ga__changeAdminAllContracts();

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

    Proposal.ProposalDetail memory proposal = _buildProposal(
      roninGovernanceAdmin,
      block.timestamp + PROPOSAL_DURATION,
      tos,
      values,
      callDatas
    );
    _executeProposal(roninGovernanceAdmin, trustedOrgContract, proposal);

    CONFIG.setAddress(network(), Contract.RoninGovernanceAdmin.key(), address(_newGA));

    // [C2.] The `doctor` will withdraw the locked fund.
    _doctor__recoverFund();

    /*
     * [C3.] The `doctor` will upgrade the Bridge Tracking contract to remove the recovery method.
     * [C4.] The `doctor` will transfer admin to BridgeManager.
     */
    _doctor__rollbackBridgeTracking();

    _migrator__disableMigrate();
  }

  function _sys__loadContracts() internal {
    roninGovernanceAdmin = RoninGovernanceAdmin(
      config.getAddressFromCurrentNetwork(Contract.RoninGovernanceAdmin.key())
    );
    trustedOrgContract = RoninTrustedOrganization(
      config.getAddressFromCurrentNetwork(Contract.RoninTrustedOrganization.key())
    );
    roninBridgeManager = config.getAddressFromCurrentNetwork(Contract.RoninBridgeManager.key());

    bridgeTracking = config.getAddressFromCurrentNetwork(Contract.BridgeTracking.key());

    fastFinalityTrackingContract = FastFinalityTracking(
      config.getAddressFromCurrentNetwork(Contract.FastFinalityTracking.key())
    );
    maintenanceContract = Maintenance(config.getAddressFromCurrentNetwork(Contract.Maintenance.key()));
    profileContract = Profile(config.getAddressFromCurrentNetwork(Contract.Profile.key()));
    slashIndicatorContract = SlashIndicator(config.getAddressFromCurrentNetwork(Contract.SlashIndicator.key()));
    stakingContract = Staking(config.getAddressFromCurrentNetwork(Contract.Staking.key()));
    stakingVestingContract = StakingVesting(config.getAddressFromCurrentNetwork(Contract.StakingVesting.key()));
    validatorContract = RoninValidatorSet(config.getAddressFromCurrentNetwork(Contract.RoninValidatorSet.key()));

    allDPoSContracts.push(payable(address(trustedOrgContract)));
    allDPoSContracts.push(payable(address(fastFinalityTrackingContract)));
    allDPoSContracts.push(payable(address(maintenanceContract)));
    allDPoSContracts.push(payable(address(profileContract)));
    allDPoSContracts.push(payable(address(slashIndicatorContract)));
    allDPoSContracts.push(payable(address(stakingContract)));
    allDPoSContracts.push(payable(address(stakingVestingContract)));
    allDPoSContracts.push(payable(address(validatorContract)));
  }

  function _node__changeStorage() internal {
    // Cheat storage slot of impl in Trusted Org Proxy
    vm.store(address(trustedOrgContract), bytes32($_IMPL_SLOT), bytes32(uint256(uint160(TRUSTED_ORG_RECOVERY_LOGIC))));
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
    callDatas[0] = abi.encodeCall(GovernanceAdmin.changeProxyAdmin, (bridgeTracking, doctor));

    targets[1] = address(DEPRECATED_BRIDGE_REWARD);
    callDatas[1] = abi.encodeCall(BridgeReward.initializeREP2, ());
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
        TContract contractType = config.getContractTypeFromCurrentNetwok(allContracts[i]);

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

  function _eoa__changeAdminToGA() internal {
    bool shouldPrankOnly = CONFIG.isBroadcastDisable();

    if (shouldPrankOnly) {
      vm.prank(BAO_EOA);
    } else {
      vm.broadcast(BAO_EOA);
    }
    TransparentUpgradeableProxy(payable(address(profileContract))).changeAdmin(address(roninGovernanceAdmin));

    if (shouldPrankOnly) {
      vm.prank(BAO_EOA);
    } else {
      vm.broadcast(BAO_EOA);
    }
    TransparentUpgradeableProxy(payable(address(fastFinalityTrackingContract))).changeAdmin(
      address(roninGovernanceAdmin)
    );
  }

  function _ga__initContracts()
    internal
    view
    returns (bytes[] memory callDatas, address[] memory targets, uint256[] memory values)
  {
    // See https://www.notion.so/skymavis/DPoS-Gateway-Contract-list-58e189d5feab435d9b78b04a3012155c?pvs=4#67e1c4291c834c5980a6915fc5489865
    targets = new address[](9);
    callDatas = new bytes[](9);
    values = new uint256[](9);

    targets[0] = address(maintenanceContract);
    callDatas[0] = abi.encodeCall(
      TransparentUpgradeableProxyV2.functionDelegateCall,
      abi.encodeCall(Maintenance.initializeV3, (address(profileContract)))
    );

    targets[1] = address(validatorContract);
    callDatas[1] = abi.encodeCall(
      TransparentUpgradeableProxyV2.functionDelegateCall,
      abi.encodeCall(RoninValidatorSet.initializeV4, (address(profileContract)))
    );

    targets[2] = address(profileContract);
    callDatas[2] = abi.encodeCall(
      TransparentUpgradeableProxyV2.functionDelegateCall,
      abi.encodeCall(Profile.initializeV2, (address(stakingContract), address(trustedOrgContract)))
    );

    targets[3] = address(profileContract);
    callDatas[3] = abi.encodeCall(
      TransparentUpgradeableProxyV2.functionDelegateCall,
      abi.encodeCall(Profile.initializeV3, (PROFILE_PUBKEY_CHANGE_COOLDOWN))
    );

    targets[4] = address(trustedOrgContract);
    callDatas[4] = abi.encodeCall(
      TransparentUpgradeableProxyV2.functionDelegateCall,
      abi.encodeCall(RoninTrustedOrganization.initializeV2, (address(profileContract)))
    );

    targets[5] = address(stakingContract);
    callDatas[5] = abi.encodeCall(
      TransparentUpgradeableProxyV2.functionDelegateCall,
      abi.encodeCall(Staking.initializeV3, (address(profileContract)))
    );

    targets[6] = address(stakingContract);
    callDatas[6] = abi.encodeCall(
      TransparentUpgradeableProxyV2.functionDelegateCall,
      abi.encodeCall(Staking.initializeV4, (address(roninGovernanceAdmin), STAKING_MIGRATOR))
    );

    // [C1.] The `MIGRATOR_ROLE` in the Staking will migrate the list of `wasAdmin`.
    {
      targets[7] = address(stakingContract);
      callDatas[7] = abi.encodeCall(
        TransparentUpgradeableProxyV2.functionDelegateCall,
        abi.encodeCall(AccessControl.grantRole, (MIGRATOR_ROLE, address(roninGovernanceAdmin)))
      );

      targets[8] = address(stakingContract);
      callDatas[8] = abi.encodeCall(TransparentUpgradeableProxyV2.functionDelegateCall, _migrator__migrateWasAdmin());
    }
  }

  function _migrator__migrateWasAdmin() internal view returns (bytes memory) {
    (address[] memory poolIds, address[] memory admins, bool[] memory flags) = _parseMigrateData(MIGRATE_DATA_PATH);
    return abi.encodeCall(Staking.migrateWasAdmin, (poolIds, admins, flags));
  }

  function _migrator__disableMigrate() internal {
    vm.prank(STAKING_MIGRATOR);
    stakingContract.disableMigrateWasAdmin();

    address[] memory poolIds = new address[](1);
    address[] memory admins = new address[](1);
    bool[] memory flags = new bool[](1);

    vm.prank(STAKING_MIGRATOR);
    vm.expectRevert(abi.encodeWithSelector(IStaking.ErrMigrateWasAdminAlreadyDone.selector));
    stakingContract.migrateWasAdmin(poolIds, admins, flags);
  }

  function _ga__changeAdminAllContracts()
    internal
    returns (bytes[] memory callDatas, address[] memory targets, uint256[] memory values)
  {
    address payable[] memory allContracts = allDPoSContracts;

    bool shouldPrankOnly = CONFIG.isBroadcastDisable();

    if (shouldPrankOnly) {
      vm.prank(DEPLOYER);
    } else {
      vm.broadcast(DEPLOYER);
    }
    _newGA = address(
      new RoninGovernanceAdmin(block.chainid, address(trustedOrgContract), address(validatorContract), 14 days)
    );

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
      } else {
        console.log("Contract to change admin:".cyan(), vm.getLabel(allContracts[i]));
        contractsToChangeAdmin.push(allContracts[i]);
      }
    }

    uint256 innerCallCount = contractsToChangeAdmin.length;
    console.log("Number contract to change admin:", innerCallCount);

    callDatas = new bytes[](innerCallCount);
    targets = contractsToChangeAdmin;
    values = new uint256[](innerCallCount);

    for (uint256 i; i < innerCallCount; ++i) {
      callDatas[i] = abi.encodeCall(TransparentUpgradeableProxy.changeAdmin, (_newGA));
    }
  }

  function _doctor__recoverFund() internal {
    address doctor = ADMIN_TMP_BRIDGE_TRACKING;

    // Step 3
    bool shouldPrankOnly = CONFIG.isBroadcastDisable();

    if (shouldPrankOnly) {
      vm.prank(DEPLOYER);
    } else {
      vm.broadcast(DEPLOYER);
    }
    address logic = address(new BridgeTrackingRecoveryLogic());

    if (shouldPrankOnly) {
      vm.prank(doctor);
    } else {
      vm.broadcast(doctor);
    }
    TransparentUpgradeableProxyV2(payable((bridgeTracking))).upgradeTo(logic);

    if (shouldPrankOnly) {
      vm.prank(doctor);
    } else {
      vm.broadcast(doctor);
    }
    TransparentUpgradeableProxyV2(payable((bridgeTracking))).functionDelegateCall(
      abi.encodeCall(BridgeTrackingRecoveryLogic.recoverFund, ())
    );

    uint256 balanceAfter = doctor.balance;
    console.log("balanceBefore", balanceBefore);
    console.log("balanceAfter", balanceAfter);
    uint256 recoveredFund = balanceAfter - balanceBefore;
    console.log("recoveredFund", recoveredFund);
  }

  function _doctor__rollbackBridgeTracking() internal {
    address doctor = ADMIN_TMP_BRIDGE_TRACKING;
    bool shouldPrankOnly = CONFIG.isBroadcastDisable();

    if (shouldPrankOnly) {
      vm.prank(DEPLOYER);
    } else {
      vm.broadcast(DEPLOYER);
    }
    address logic = address(new BridgeTracking());

    if (shouldPrankOnly) {
      vm.prank(doctor);
    } else {
      vm.broadcast(doctor);
    }
    TransparentUpgradeableProxyV2(payable((bridgeTracking))).upgradeTo(logic);

    if (shouldPrankOnly) {
      vm.prank(doctor);
    } else {
      vm.broadcast(doctor);
    }
    TransparentUpgradeableProxyV2(payable((bridgeTracking))).changeAdmin(roninBridgeManager);
  }
}
