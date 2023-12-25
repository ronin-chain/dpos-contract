// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 as console } from "forge-std/console2.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";
import { Contract } from "script/utils/Contract.sol";
import { DefaultContract } from "foundry-deployment-kit/utils/DefaultContract.sol";
import { BridgeTracking } from "@ronin/contracts/ronin/gateway/BridgeTracking.sol";
import { RoninGovernanceAdmin } from "@ronin/contracts/ronin/RoninGovernanceAdmin.sol";
import { BridgeTrackingRecoveryLogic } from "./contracts/BridgeTrackingRecoveryLogic.sol";
import { BridgeReward } from "@ronin/contracts/ronin/gateway/BridgeReward.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";

contract Simulation__20231019_RecoverFund is RoninMigration {
  BridgeReward public constant DEPRECATED_BRIDGE_REWARD = BridgeReward(0x1C952D6717eBFd2E92E5f43Ef7C1c3f7677F007D);

  function run() public {
    address admin = makeAddr("eoa-admin");
    RoninGovernanceAdmin roninGovernanceAdmin =
      RoninGovernanceAdmin(config.getAddressFromCurrentNetwork(Contract.RoninGovernanceAdmin.key()));
    address bridgeTracking = config.getAddressFromCurrentNetwork(Contract.BridgeTracking.key());

    uint256 balanceBefore = admin.balance;
    console.log("balanceBefore", balanceBefore);

    vm.startPrank(address(roninGovernanceAdmin));
    roninGovernanceAdmin.changeProxyAdmin((bridgeTracking), admin);
    DEPRECATED_BRIDGE_REWARD.initializeREP2();
    vm.stopPrank();

    vm.startPrank(admin);
    address logic = address(new BridgeTrackingRecoveryLogic());
    TransparentUpgradeableProxyV2(payable((bridgeTracking))).upgradeTo(logic);
    TransparentUpgradeableProxyV2(payable((bridgeTracking))).functionDelegateCall(
      abi.encodeCall(BridgeTrackingRecoveryLogic.recoverFund, ())
    );
    vm.stopPrank();

    uint256 balanceAfter = admin.balance;
    console.log("balanceAfter", balanceAfter);
    uint256 recoveredFund = balanceAfter - balanceBefore;
    console.log("recoveredFund", recoveredFund);
  }
}
