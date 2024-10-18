// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";
import { Contract } from "script/utils/Contract.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { IRoninGovernanceAdmin } from "@ronin/contracts/interfaces/IRoninGovernanceAdmin.sol";
import { IGovernanceAdmin } from "@ronin/contracts/interfaces/extensions/IGovernanceAdmin.sol";
import { BridgeTrackingRecoveryLogic } from "./contracts/BridgeTrackingRecoveryLogic.sol";
import { IRoninTrustedOrganization } from "@ronin/contracts/interfaces/IRoninTrustedOrganization.sol";
import { IBridgeReward } from "@ronin/contracts/interfaces/bridge/IBridgeReward.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";

import {
  IRoninTrustedOrganization,
  RoninTrustedOrganization
} from "@ronin/contracts/multi-chains/RoninTrustedOrganization.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";

contract Simulation__20231019_RecoverFund is RoninMigration {
  IBridgeReward public constant DEPRECATED_BRIDGE_REWARD = IBridgeReward(0x1C952D6717eBFd2E92E5f43Ef7C1c3f7677F007D);

  /**
   * Steps:
   * 1. [hardfork] Change logic of ronin trusted org
   * 2. Change admin of bridge tracking to a temp admin
   * 3. Use temp admin in (2) to upgrade bridge tracking to bridge tracking recovery logic
   * 4. Run script to recover fund
   */
  function run() public onlyOn(DefaultNetwork.RoninMainnet.key()) {
    address admin = sender();
    console.log("Default sender:", admin);

    address deployer = 0xFE490b68E64B190B415Bb92F8D2F7566243E6ea0; // Mainnet Shadow deployer address

    IRoninGovernanceAdmin roninGovernanceAdmin =
      IRoninGovernanceAdmin(loadContract(Contract.RoninGovernanceAdmin.key()));
    RoninTrustedOrganization trustedOrgContract =
      RoninTrustedOrganization(loadContract(Contract.RoninTrustedOrganization.key()));
    address bridgeTracking = loadContract(Contract.BridgeTracking.key());

    // _initBalanceForUser(trustedOrgContract);

    // Step 2

    uint256 balanceBefore = admin.balance;
    console.log("balanceBefore", balanceBefore);

    address[] memory tos = new address[](2);
    bytes[] memory callDatas = new bytes[](2);
    uint256[] memory values = new uint256[](2);

    tos[0] = address(roninGovernanceAdmin);
    tos[1] = address(DEPRECATED_BRIDGE_REWARD);
    callDatas[0] = abi.encodeCall(IGovernanceAdmin.changeProxyAdmin, (bridgeTracking, admin));
    callDatas[1] = abi.encodeCall(IBridgeReward.initializeREP2, ());

    Proposal.ProposalDetail memory proposal =
      LibProposal.buildProposal(roninGovernanceAdmin, vm.getBlockTimestamp() + 20 minutes, tos, values, callDatas);
    LibProposal.executeProposal(roninGovernanceAdmin, trustedOrgContract, proposal);

    // Step 3
    bool shouldPrankOnly = vme.isPostChecking();

    if (shouldPrankOnly) {
      vm.prank(deployer);
    } else {
      vm.broadcast(deployer);
    }
    address logic = address(new BridgeTrackingRecoveryLogic());

    if (shouldPrankOnly) {
      vm.prank(admin);
    } else {
      vm.broadcast(admin);
    }
    TransparentUpgradeableProxyV2(payable((bridgeTracking))).upgradeTo(logic);

    if (shouldPrankOnly) {
      vm.prank(admin);
    } else {
      vm.broadcast(admin);
    }
    TransparentUpgradeableProxyV2(payable((bridgeTracking))).functionDelegateCall(
      abi.encodeCall(BridgeTrackingRecoveryLogic.recoverFund, ())
    );

    uint256 balanceAfter = admin.balance;
    console.log("balanceAfter", balanceAfter);
    uint256 recoveredFund = balanceAfter - balanceBefore;
    console.log("recoveredFund", recoveredFund);
  }

  function _initBalanceForUser(
    RoninTrustedOrganization trustedOrgContract
  ) internal {
    address genesisUser = sender();
    bool shouldPrankOnly = vme.isPostChecking();

    IRoninTrustedOrganization.TrustedOrganization[] memory allTrustedOrgs =
      trustedOrgContract.getAllTrustedOrganizations();

    for (uint256 i = 0; i < allTrustedOrgs.length; ++i) {
      if (shouldPrankOnly) {
        vm.prank(genesisUser);
      } else {
        vm.broadcast(genesisUser);
      }
      payable(allTrustedOrgs[i].governor).transfer(2 ether);
    }
  }
}
