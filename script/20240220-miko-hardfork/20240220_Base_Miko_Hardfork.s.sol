// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TContract } from "@fdk/types/Types.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { JSONParserLib } from "@solady/utils/JSONParserLib.sol";

import { IStaking } from "@ronin/contracts/interfaces/staking/IStaking.sol";
import { IProfile } from "@ronin/contracts/interfaces/IProfile.sol";
import { IRoninValidatorSet } from "@ronin/contracts/interfaces/validator/IRoninValidatorSet.sol";
import { IMaintenance } from "@ronin/contracts/interfaces/IMaintenance.sol";
import { IStakingVesting } from "@ronin/contracts/interfaces/IStakingVesting.sol";
import { IFastFinalityTracking } from "@ronin/contracts/interfaces/IFastFinalityTracking.sol";
import { ISlashIndicator } from "@ronin/contracts/interfaces/slash-indicator/ISlashIndicator.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IRoninGovernanceAdmin } from "@ronin/contracts/interfaces/IRoninGovernanceAdmin.sol";
import { IRoninTrustedOrganization } from "@ronin/contracts/interfaces/IRoninTrustedOrganization.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { MikoConfig } from "./MikoConfig.s.sol";
import { console } from "forge-std/console.sol";
import { Contract } from "script/utils/Contract.sol";

contract Proposal__Base_20240220_MikoHardfork is MikoConfig {
  using LibProxy for *;
  using StdStyle for *;
  using JSONParserLib for *;

  uint256 balanceBefore;

  address internal _newGA;

  address payable[] internal allDPoSContracts;
  address[] internal contractsToUpgrade;
  address[] internal contractsToChangeAdmin;
  address[] internal contractsToChangeDefaultAdminRole;
  TContract[] internal contractTypesToUpgrade;

  IRoninGovernanceAdmin internal roninGovernanceAdmin;
  IRoninTrustedOrganization internal trustedOrgContract;

  address internal bridgeTracking;
  address internal roninBridgeManager;
  ISlashIndicator internal slashIndicatorContract;
  IFastFinalityTracking internal fastFinalityTrackingContract;
  IProfile internal profileContract;
  IStaking internal stakingContract;
  IStakingVesting internal stakingVestingContract;
  IMaintenance internal maintenanceContract;
  IRoninValidatorSet internal validatorContract;

  /**
   * See `README.md`
   */
  function run() public virtual onlyOn(DefaultNetwork.RoninMainnet.key()) {
    address sender = sender();
    console.log("Default sender:", sender);

    _sys__loadContracts();
    // _node__changeStorage();
  }

  function _sys__loadContracts() internal {
    roninGovernanceAdmin = IRoninGovernanceAdmin(loadContract(Contract.RoninGovernanceAdmin.key()));
    trustedOrgContract = IRoninTrustedOrganization(loadContract(Contract.RoninTrustedOrganization.key()));
    roninBridgeManager = loadContract(Contract.RoninBridgeManager.key());

    bridgeTracking = loadContract(Contract.BridgeTracking.key());

    fastFinalityTrackingContract = IFastFinalityTracking(loadContract(Contract.FastFinalityTracking.key()));
    maintenanceContract = IMaintenance(loadContract(Contract.Maintenance.key()));
    profileContract = IProfile(loadContract(Contract.Profile.key()));
    slashIndicatorContract = ISlashIndicator(loadContract(Contract.SlashIndicator.key()));
    stakingContract = IStaking(loadContract(Contract.Staking.key()));
    stakingVestingContract = IStakingVesting(loadContract(Contract.StakingVesting.key()));
    validatorContract = IRoninValidatorSet(loadContract(Contract.RoninValidatorSet.key()));

    allDPoSContracts.push(payable(address(trustedOrgContract)));
    allDPoSContracts.push(payable(address(fastFinalityTrackingContract)));
    allDPoSContracts.push(payable(address(maintenanceContract)));
    allDPoSContracts.push(payable(address(profileContract)));
    allDPoSContracts.push(payable(address(slashIndicatorContract)));
    allDPoSContracts.push(payable(address(stakingContract)));
    allDPoSContracts.push(payable(address(stakingVestingContract)));
    allDPoSContracts.push(payable(address(validatorContract)));
  }

  function _sys__parseMigrateData(string memory path)
    internal
    view
    returns (address[] memory poolIds, address[] memory admins, bool[] memory flags)
  {
    string memory raw = vm.readFile(path);
    JSONParserLib.Item memory data = raw.parse();
    uint256 size = data.size();
    console.log("data size", size);

    poolIds = new address[](size);
    admins = new address[](size);
    flags = new bool[](size);

    for (uint256 i; i < size; ++i) {
      poolIds[i] = vm.parseAddress(data.at(i).at('"cid"').value().decodeString());
      admins[i] = vm.parseAddress(data.at(i).at('"admin"').value().decodeString());
      flags[i] = true;

      console.log("\nPool ID:".cyan(), vm.toString(poolIds[i]));
      console.log("Admin:".cyan(), vm.toString(admins[i]));
      console.log("Flags:".cyan(), flags[i]);
    }
  }

  function _node__changeStorage() internal {
    // Cheat storage slot of impl in Trusted Org Proxy
    vm.store(address(trustedOrgContract), bytes32($_IMPL_SLOT), bytes32(uint256(uint160(TRUSTED_ORG_RECOVERY_LOGIC))));
    // vm.store(address(profileContract), bytes32($_ADMIN_SLOT), bytes32(uint256(uint160(BAO_EOA))));
    // vm.store(address(fastFinalityTrackingContract), bytes32($_ADMIN_SLOT), bytes32(uint256(uint160(BAO_EOA))));
  }
}
