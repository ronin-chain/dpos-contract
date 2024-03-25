// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IBaseStaking } from "@ronin/contracts/interfaces/staking/IBaseStaking.sol";
import {
  TransparentUpgradeableProxy,
  TransparentUpgradeableProxyV2
} from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { console2 as console } from "forge-std/console2.sol";
import { TContract } from "foundry-deployment-kit/types/Types.sol";
import { LibProxy } from "foundry-deployment-kit/libraries/LibProxy.sol";
import { DefaultNetwork } from "foundry-deployment-kit/utils/DefaultNetwork.sol";
import { RoninTrustedOrganization, Proposal, RoninMigration, RoninGovernanceAdmin } from "script/RoninMigration.s.sol";
import { Contract } from "script/utils/Contract.sol";
import { Maintenance } from "@ronin/contracts/ronin/Maintenance.sol";
import { Staking } from "@ronin/contracts/ronin/staking/Staking.sol";
import "@ronin/contracts/ronin/profile/Profile_Mainnet.sol";

contract Migration__20242103_UpgradeReleaseV0_7_7_Mainnet is RoninMigration {
  using LibProxy for *;
  using StdStyle for *;

  uint256 private constant NEW_MIN_OFFSET_TO_START_SCHEDULE = 1;

  address[] private contractsToUpgrade;
  TContract[] private contractTypesToUpgrade;

  function run() public onlyOn(DefaultNetwork.RoninMainnet.key()) {
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
    innerCallCount += 2;
    console.log("Number contract to upgrade:", innerCallCount);

    bytes[] memory callDatas = new bytes[](innerCallCount);
    address[] memory targets = new address[](innerCallCount);
    uint256[] memory values = new uint256[](innerCallCount);
    address[] memory logics = new address[](innerCallCount);

    _buildSetMaintenanceConfigProposal(targets, callDatas, innerCallCount - 2);
    _buildMigrateProfileProposal(targets, callDatas, innerCallCount - 1);

    for (uint256 i; i < innerCallCount - 2; ++i) {
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
      _buildProposal(governanceAdmin, block.timestamp + 14 days, targets, values, callDatas);
    _executeProposal(governanceAdmin, trustedOrg, proposal);
  }

  function _postCheck() internal override {
    super._postCheck();
    v0_7_7Postcheck();
  }

  function _buildMigrateProfileProposal(address[] memory targets, bytes[] memory callDatas, uint256 at) internal view {
    Profile_Mainnet profile = Profile_Mainnet(loadContract(Contract.Profile.key()));
    targets[at] = address(profile);
    callDatas[at] = abi.encodeCall(
      TransparentUpgradeableProxyV2.functionDelegateCall, (abi.encodeCall(Profile_Mainnet.migrateOmissionREP4, ()))
    );
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

  function v0_7_7Postcheck() internal {
    TConsensus[] memory lostAddr = new TConsensus[](3);
    lostAddr[0] = TConsensus.wrap(0x454f6C34F0cfAdF1733044Fdf8B06516BD1E9529);
    lostAddr[1] = TConsensus.wrap(0xD7fEf73d95ccEdb26483fd3C6C48393e50708159);
    lostAddr[2] = TConsensus.wrap(0xbD4bf317Da1928CC2f9f4DA9006401f3944A0Ab5);

    Profile_Mainnet profile = Profile_Mainnet(loadContract(Contract.Profile.key()));
    profile.getId2Profile(TConsensus.unwrap(lostAddr[0]));
    profile.getId2Profile(TConsensus.unwrap(lostAddr[1]));
    profile.getId2Profile(TConsensus.unwrap(lostAddr[2]));

    profile.getConsensus2Id(lostAddr[0]);
    profile.getConsensus2Id(lostAddr[1]);
    profile.getConsensus2Id(lostAddr[2]);

    vm.expectRevert("Not supported");
    profile.changeConsensusAddr(
      0x454f6C34F0cfAdF1733044Fdf8B06516BD1E9529, TConsensus.wrap(0x454f6C34F0cfAdF1733044Fdf8B06516BD1E9529)
    );

    Staking staking = Staking(loadContract(Contract.Staking.key()));
    staking.getRewards(address(0x1111111), lostAddr);
  }
}
