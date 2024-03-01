// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TContract } from "foundry-deployment-kit/types/Types.sol";
import { LibProxy } from "foundry-deployment-kit/libraries/LibProxy.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { JSONParserLib } from "lib/foundry-deployment-kit/lib/solady/src/utils/JSONParserLib.sol";

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
import "./MikoConfig.s.sol";

contract Proposal__Base_20240220_MikoHardfork is MikoConfig {
  using LibProxy for *;
  using StdStyle for *;
  using ArrayReplaceLib for *;
  using JSONParserLib for *;

  uint256 balanceBefore;

  address internal _newGA;

  address payable[] internal allDPoSContracts;
  address[] internal contractsToUpgrade;
  address[] internal contractsToChangeAdmin;
  address[] internal contractsToChangeDefaultAdminRole;
  TContract[] internal contractTypesToUpgrade;

  RoninGovernanceAdmin internal roninGovernanceAdmin;
  RoninTrustedOrganization internal trustedOrgContract;

  address internal bridgeTracking;
  address internal roninBridgeManager;
  SlashIndicator internal slashIndicatorContract;
  FastFinalityTracking internal fastFinalityTrackingContract;
  Profile internal profileContract;
  Staking internal stakingContract;
  StakingVesting internal stakingVestingContract;
  Maintenance internal maintenanceContract;
  RoninValidatorSet internal validatorContract;

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

  function _sys__parseMigrateData(
    string memory path
  ) internal view returns (address[] memory poolIds, address[] memory admins, bool[] memory flags) {
    string memory raw = vm.readFile(path);
    JSONParserLib.Item memory data = raw.parse();
    uint256 size = data.size();
    console.log("size", size);

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
