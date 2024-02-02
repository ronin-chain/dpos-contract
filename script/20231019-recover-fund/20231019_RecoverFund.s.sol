// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 as console } from "forge-std/console2.sol";
import { Proposal, RoninMigration } from "script/RoninMigration.s.sol";
import { Contract } from "script/utils/Contract.sol";
import { DefaultNetwork } from "foundry-deployment-kit/utils/DefaultNetwork.sol";
import { DefaultContract } from "foundry-deployment-kit/utils/DefaultContract.sol";
import { BridgeTracking } from "@ronin/contracts/ronin/gateway/BridgeTracking.sol";
import { GovernanceAdmin, RoninGovernanceAdmin } from "@ronin/contracts/ronin/RoninGovernanceAdmin.sol";
import { BridgeTrackingRecoveryLogic } from "./contracts/BridgeTrackingRecoveryLogic.sol";
import { RoninTrustedOrganization } from "@ronin/contracts/multi-chains/RoninTrustedOrganization.sol";
import { BridgeReward } from "@ronin/contracts/ronin/gateway/BridgeReward.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";

import { IRoninTrustedOrganization, RoninTrustedOrganization } from "@ronin/contracts/multi-chains/RoninTrustedOrganization.sol";

contract Simulation__20231019_RecoverFund is RoninMigration {
  BridgeReward public constant DEPRECATED_BRIDGE_REWARD = BridgeReward(0x1C952D6717eBFd2E92E5f43Ef7C1c3f7677F007D);

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

    RoninGovernanceAdmin roninGovernanceAdmin = RoninGovernanceAdmin(config.getAddressFromCurrentNetwork(Contract.RoninGovernanceAdmin.key()));
    RoninTrustedOrganization trustedOrgContract = RoninTrustedOrganization(config.getAddressFromCurrentNetwork(Contract.RoninTrustedOrganization.key()));
    address bridgeTracking = config.getAddressFromCurrentNetwork(Contract.BridgeTracking.key());

    // _initBalanceForUser(trustedOrgContract);

    // Step 2

    uint256 balanceBefore = admin.balance;
    console.log("balanceBefore", balanceBefore);

    address[] memory tos = new address[](2);
    bytes[] memory callDatas = new bytes[](2);
    uint256[] memory values = new uint256[](2);

    tos[0] = address(roninGovernanceAdmin);
    tos[1] = address(DEPRECATED_BRIDGE_REWARD);
    callDatas[0] = abi.encodeCall(GovernanceAdmin.changeProxyAdmin, (bridgeTracking, admin));
    callDatas[1] = abi.encodeCall(BridgeReward.initializeREP2, ());

    Proposal.ProposalDetail memory proposal = _buildProposal(roninGovernanceAdmin, block.timestamp + 20 minutes, tos, values, callDatas);
    _executeProposal(roninGovernanceAdmin, trustedOrgContract, proposal);

    // Step 3
    bool shouldPrankOnly = CONFIG.isBroadcastDisable();

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

  function _initBalanceForUser(RoninTrustedOrganization trustedOrgContract) internal {
    address genesisUser = sender();
    bool shouldPrankOnly = CONFIG.isBroadcastDisable();

    IRoninTrustedOrganization.TrustedOrganization[] memory allTrustedOrgs = trustedOrgContract.getAllTrustedOrganizations();

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
