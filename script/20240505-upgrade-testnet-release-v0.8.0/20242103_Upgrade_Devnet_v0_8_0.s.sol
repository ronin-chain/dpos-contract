// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IBaseStaking } from "@ronin/contracts/interfaces/staking/IBaseStaking.sol";
import {
  TransparentUpgradeableProxy,
  TransparentUpgradeableProxyV2
} from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { console } from "forge-std/console.sol";
import { TContract } from "@fdk/types/Types.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import {
  ISharedArgument,
  RoninTrustedOrganization,
  Proposal,
  RoninMigration,
  RoninGovernanceAdmin
} from "script/RoninMigration.s.sol";
import { ISharedArgument } from "script/interfaces/ISharedArgument.sol";
import { Network } from "script/utils/Network.sol";
import { Contract } from "script/utils/Contract.sol";
import { Maintenance } from "@ronin/contracts/ronin/Maintenance.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";
import { SlashIndicator } from "@ronin/contracts/ronin/slash-indicator/SlashIndicator.sol";
import { RoninRandomBeacon, RoninRandomBeaconDeploy } from "script/contracts/RoninRandomBeaconDeploy.s.sol";
import {
  RoninValidatorSetREP10Migrator,
  RoninValidatorSetREP10MigratorLogicDeploy
} from "script/contracts/RoninValidatorSetREP10MigratorLogicDeploy.s.sol";

contract Migration__20250505_Upgrade_Devnet_Release_V0_8_0 is RoninMigration {
  using LibProxy for *;
  using StdStyle for *;

  address[] private contractsToUpgrade;
  TContract[] private contractTypesToUpgrade;

  RoninRandomBeacon private randomBeacon;
  address private roninValidatorSetREP10LogicMigrator;

  function run() public {
    RoninGovernanceAdmin governanceAdmin = RoninGovernanceAdmin(loadContract(Contract.RoninGovernanceAdmin.key()));
    RoninTrustedOrganization trustedOrg =
      RoninTrustedOrganization(loadContract(Contract.RoninTrustedOrganization.key()));

    ISharedArgument.SharedParameter memory param = config.sharedArguments();

    address payable[] memory allContracts = config.getAllAddresses(network());

    randomBeacon = new RoninRandomBeaconDeploy().run();

    vm.startBroadcast(sender());

    randomBeacon.initialize({
      profile: loadContract(Contract.Profile.key()),
      staking: loadContract(Contract.Staking.key()),
      trustedOrg: address(trustedOrg),
      validatorSet: loadContract(Contract.RoninValidatorSet.key()),
      slashIndicator: loadContract(Contract.SlashIndicator.key()),
      slashThreshold: param.roninRandomBeacon.slashThreshold,
      initialSeed: param.roninRandomBeacon.initialSeed,
      activatedAtPeriod: param.roninRandomBeacon.activatedAtPeriod,
      validatorTypes: param.roninRandomBeacon.validatorTypes,
      thresholds: param.roninRandomBeacon.thresholds
    });

    vm.stopBroadcast();

    roninValidatorSetREP10LogicMigrator = new RoninValidatorSetREP10MigratorLogicDeploy().run();

    _recordContractToUpgrade(address(governanceAdmin), allContracts); // Record contracts to upgrade

    (address[] memory targets, uint256[] memory values, bytes[] memory callDatas) = _buildProposalData(param);

    Proposal.ProposalDetail memory proposal =
      LibProposal.buildProposal(governanceAdmin, block.timestamp + 14 days, targets, values, callDatas);
    LibProposal.executeProposal(governanceAdmin, trustedOrg, proposal);
  }

  function _buildProposalData(ISharedArgument.SharedParameter memory param)
    internal
    returns (address[] memory targets, uint256[] memory values, bytes[] memory callDatas)
  {
    uint256 innerCallCount = contractTypesToUpgrade.length;
    console.log("Number contract to upgrade:", innerCallCount);

    callDatas = new bytes[](innerCallCount);
    targets = new address[](innerCallCount);
    values = new uint256[](innerCallCount);
    address[] memory logics = new address[](innerCallCount);

    for (uint256 i; i < innerCallCount; ++i) {
      targets[i] = contractsToUpgrade[i];

      if (contractTypesToUpgrade[i] != Contract.RoninValidatorSet.key()) {
        logics[i] = _deployLogic(contractTypesToUpgrade[i]);
        callDatas[i] = abi.encodeCall(TransparentUpgradeableProxy.upgradeTo, (logics[i]));
      }

      if (contractTypesToUpgrade[i] == Contract.RoninValidatorSet.key()) {
        callDatas[i] = abi.encodeCall(
          TransparentUpgradeableProxy.upgradeToAndCall,
          (
            roninValidatorSetREP10LogicMigrator,
            abi.encodeCall(RoninValidatorSetREP10Migrator.initialize, (address(randomBeacon)))
          )
        );

        continue;
      }

      if (contractTypesToUpgrade[i] == Contract.SlashIndicator.key()) {
        callDatas[i] = abi.encodeCall(
          TransparentUpgradeableProxy.upgradeToAndCall,
          (
            logics[i],
            abi.encodeCall(
              SlashIndicator.initializeV4,
              (
                address(randomBeacon),
                param.slashIndicator.slashRandomBeacon.randomBeaconSlashAmount,
                param.slashIndicator.slashRandomBeacon.activatedAtPeriod
              )
            )
          )
        );
      }
    }
  }

  function _recordContractToUpgrade(address gov, address payable[] memory allContracts) internal {
    for (uint256 i; i < allContracts.length; i++) {
      address proxyAdmin = allContracts[i].getProxyAdmin(false);
      if (proxyAdmin != gov) {
        console.log(
          unicode"⚠ WARNING:".yellow(),
          string.concat(
            vm.getLabel(allContracts[i]),
            " has different ProxyAdmin. Expected: ",
            vm.getLabel(gov),
            " Got: ",
            vm.toString(proxyAdmin)
          )
        );

        continue;
      }

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

        continue;
      }

      console.log("Contract not to Upgrade:", vm.getLabel(allContracts[i]));
    }
  }
}
