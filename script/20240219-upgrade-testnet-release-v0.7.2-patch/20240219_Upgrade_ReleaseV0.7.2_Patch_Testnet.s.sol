// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { console } from "forge-std/console.sol";
import { TContract } from "@fdk/types/Types.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { IRoninTrustedOrganization, Proposal, RoninMigration } from "script/RoninMigration.s.sol";
import { IRoninGovernanceAdmin } from "@ronin/contracts/interfaces/IRoninGovernanceAdmin.sol";
import { Contract } from "script/utils/Contract.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";

contract Migration__20240219_UpgradeReleaseV0_7_2_Patch_Testnet is RoninMigration {
  using LibProxy for *;
  using StdStyle for *;

  address[] private contractsToUpgrade;
  TContract[] private contractTypesToUpgrade;

  function run() public onlyOn(DefaultNetwork.RoninTestnet.key()) {
    IRoninGovernanceAdmin governanceAdmin = IRoninGovernanceAdmin(loadContract(Contract.RoninGovernanceAdmin.key()));
    IRoninTrustedOrganization trustedOrg =
      IRoninTrustedOrganization(loadContract(Contract.RoninTrustedOrganization.key()));
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
    console.log("Number contract to upgrade:", innerCallCount);

    bytes[] memory callDatas = new bytes[](innerCallCount);
    address[] memory targets = contractsToUpgrade;
    uint256[] memory values = new uint256[](innerCallCount);
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

    Proposal.ProposalDetail memory proposal =
      LibProposal.buildProposal(governanceAdmin, vm.getBlockTimestamp() + 14 days, targets, values, callDatas);
    LibProposal.executeProposal(governanceAdmin, trustedOrg, proposal);
  }
}
