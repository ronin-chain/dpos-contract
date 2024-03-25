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

  address public constant SKY_MAVIS_GOVERNOR = 0xe880802580a1fbdeF67ACe39D1B21c5b2C74f059; // op:
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

    _proposeProposal(governanceAdmin, trustedOrg, proposal, SKY_MAVIS_GOVERNOR);

    CONFIG.setPostCheckingStatus(true);
    _voteProposalUntilSuccess(governanceAdmin, trustedOrg, proposal);
    CONFIG.setPostCheckingStatus(false);
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
    TConsensus[] memory allCss = new TConsensus[](31);
    allCss[0] = TConsensus.wrap(0xca54a1700e0403Dcb531f8dB4aE3847758b90B01);
    allCss[1] = TConsensus.wrap(0x07d28F88D677C4056EA6722aa35d92903b2a63da);
    allCss[2] = TConsensus.wrap(0xae53daAC1BF3c4633d4921B8C3F8d579e757F5Bc);
    allCss[3] = TConsensus.wrap(0x22C23429e46e7944D2918F2B368b799b11C417C1);
    allCss[4] = TConsensus.wrap(0x454f6C34F0cfAdF1733044Fdf8B06516BD1E9529);
    allCss[5] = TConsensus.wrap(0xD7fEf73d95ccEdb26483fd3C6C48393e50708159);
    allCss[6] = TConsensus.wrap(0xEE11d2016e9f2faE606b2F12986811F4abbe6215);
    allCss[7] = TConsensus.wrap(0x262B9fcfe8CFA900aF4D1f5c20396E969B9655DD);
    allCss[8] = TConsensus.wrap(0x4125217cE8868553e1f61BB030426eFD330c2D68);
    allCss[9] = TConsensus.wrap(0x6aaABf51C5F6D2D93212Cf7DAD73D67AFa0148d0);
    allCss[10] = TConsensus.wrap(0x4E7EA047EC7E95c7a02CB117128B94CCDd8356bf);
    allCss[11] = TConsensus.wrap(0x2bdDcaAE1C6cCd53E436179B3fc07307ee6f3eF8);
    allCss[12] = TConsensus.wrap(0xFc3e31519B551bd594235dd0eF014375a87C4e21);
    allCss[13] = TConsensus.wrap(0xbD4bf317Da1928CC2f9f4DA9006401f3944A0Ab5);
    allCss[14] = TConsensus.wrap(0x61089875fF9e506ae78C7FE9f7c388416520E386);
    allCss[15] = TConsensus.wrap(0xeC702628F44C31aCc56C3A59555be47e1f16eB1e);
    allCss[16] = TConsensus.wrap(0x6E46924371d0e910769aaBE0d867590deAC20684);
    allCss[17] = TConsensus.wrap(0xd11D9842baBd5209b9B1155e46f5878c989125b7);
    allCss[18] = TConsensus.wrap(0x32D619Dc6188409CebbC52f921Ab306F07DB085b);
    allCss[19] = TConsensus.wrap(0x20238eB5643d4D7b7Ab3C30f3bf7B8E2B85cA1e7);
    allCss[20] = TConsensus.wrap(0x03A7B98C226225e330d11D1B9177891391Fa4f80);
    allCss[21] = TConsensus.wrap(0x9B959D27840a31988410Ee69991BCF0110D61F02);
    allCss[22] = TConsensus.wrap(0xedCafC4Ad8097c2012980A2a7087d74B86bDDAf9);
    allCss[23] = TConsensus.wrap(0x52C0dcd83aa1999BA6c3b0324C8299E30207373C);
    allCss[24] = TConsensus.wrap(0x47cfcb64f8EA44d6Ea7FAB32f13EFa2f8E65Eec1);
    allCss[25] = TConsensus.wrap(0xE07D7e56588a6FD860c5073c70a099658C060F3D);
    allCss[26] = TConsensus.wrap(0x8Eec4F1c0878F73E8e09C1be78aC1465Cc16544D);
    allCss[27] = TConsensus.wrap(0x52349003240770727900b06a3B3a90f5c0219ADe);
    allCss[28] = TConsensus.wrap(0x210744C64Eea863Cf0f972e5AEBC683b98fB1984);
    allCss[29] = TConsensus.wrap(0xf41Af21F0A800dc4d86efB14ad46cfb9884FDf38);
    allCss[30] = TConsensus.wrap(0x05ad3Ded6fcc510324Af8e2631717af6dA5C8B5B);

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

    for (uint i; i < allCss.length; i++) {
      assertEq(profile.getConsensus2Id(allCss[i]), TConsensus.unwrap(allCss[i]));
    }

    vm.expectRevert("Not supported");
    profile.changeConsensusAddr(
      0x454f6C34F0cfAdF1733044Fdf8B06516BD1E9529, TConsensus.wrap(0x454f6C34F0cfAdF1733044Fdf8B06516BD1E9529)
    );

    Staking staking = Staking(loadContract(Contract.Staking.key()));
    staking.getRewards(address(0x1111111), lostAddr);

    uint[] memory rewards = staking.getRewards(address(0x4C2699150039670c792902d302E11e82bdc7043D), lostAddr);

    assertEq(rewards[0], 0);
    assertEq(rewards[1], 0);
    assertEq(rewards[2], 18081215086235332);
  }
}
