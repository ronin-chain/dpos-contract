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
import { RoninTrustedOrganization, Proposal, RoninMigration, RoninGovernanceAdmin } from "script/RoninMigration.s.sol";
import { Contract } from "script/utils/Contract.sol";
import { Maintenance } from "@ronin/contracts/ronin/Maintenance.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";

contract Migration__20242103_UpgradeReleaseV0_7_7_Testnet is RoninMigration {
  using LibProxy for *;
  using StdStyle for *;

  uint256 private constant NEW_MIN_OFFSET_TO_START_SCHEDULE = 1;

  address[] private contractsToUpgrade;
  TContract[] private contractTypesToUpgrade;

  function run() public onlyOn(DefaultNetwork.RoninTestnet.key()) {
    RoninGovernanceAdmin governanceAdmin = RoninGovernanceAdmin(loadContract(Contract.RoninGovernanceAdmin.key()));
    RoninTrustedOrganization trustedOrg =
      RoninTrustedOrganization(loadContract(Contract.RoninTrustedOrganization.key()));
    address payable[] memory allContracts = config.getAllAddresses(network());

    for (uint256 i; i < allContracts.length; ++i) {
      address proxyAdmin = allContracts[i].getProxyAdmin(false);
      if (proxyAdmin != address(governanceAdmin)) {
        console.log(
          unicode"⚠ WARNING:".yellow(),
          string.concat(
            vm.getLabel(allContracts[i]),
            " has different ProxyAdmin. Expected: ",
            vm.getLabel(address(governanceAdmin)),
            " Got: ",
            vm.toString(proxyAdmin)
          )
        );
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
    innerCallCount += 1;
    console.log("Number contract to upgrade:", innerCallCount);

    bytes[] memory callDatas = new bytes[](innerCallCount);
    address[] memory targets = new address[](innerCallCount);
    uint256[] memory values = new uint256[](innerCallCount);
    address[] memory logics = new address[](innerCallCount);

    _buildSetMaintenanceConfigProposal(targets, callDatas, innerCallCount - 1);

    for (uint256 i; i < innerCallCount - 1; ++i) {
      targets[i] = contractsToUpgrade[i];
      logics[i] = _deployLogic(contractTypesToUpgrade[i]);
      callDatas[i] = abi.encodeCall(TransparentUpgradeableProxy.upgradeTo, (logics[i]));

      if (contractTypesToUpgrade[i] == Contract.Maintenance.key()) {
        callDatas[i] = abi.encodeCall(
          TransparentUpgradeableProxy.upgradeToAndCall, (logics[i], abi.encodeCall(Maintenance.initializeV4, ()))
        );
      }
    }

    Proposal.ProposalDetail memory proposal =
      LibProposal.buildProposal(governanceAdmin, vm.getBlockTimestamp() + 14 days, targets, values, callDatas);
    LibProposal.executeProposal(governanceAdmin, trustedOrg, proposal);
  }

  function _buildSetMaintenanceConfigProposal(
    address[] memory targets,
    bytes[] memory callDatas,
    uint256 at
  ) internal view {
    Maintenance maintenance = Maintenance(loadContract(Contract.Maintenance.key()));
    targets[at] = address(maintenance);
    callDatas[at] = abi.encodeCall(
      TransparentUpgradeableProxyV2.functionDelegateCall,
      (
        abi.encodeCall(
          Maintenance.setMaintenanceConfig,
          (
            maintenance.minMaintenanceDurationInBlock(),
            maintenance.maxMaintenanceDurationInBlock(),
            NEW_MIN_OFFSET_TO_START_SCHEDULE,
            maintenance.maxOffsetToStartSchedule(),
            maintenance.maxSchedule(),
            maintenance.cooldownSecsToMaintain()
          )
        )
      )
    );
  }
}
