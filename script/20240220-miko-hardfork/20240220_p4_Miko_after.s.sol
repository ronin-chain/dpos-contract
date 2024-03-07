// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TContract } from "foundry-deployment-kit/types/Types.sol";
import { LibProxy } from "foundry-deployment-kit/libraries/LibProxy.sol";
import { StdStyle } from "forge-std/StdStyle.sol";

import {
  BridgeTrackingRecoveryLogic,
  BridgeTracking
} from "../20231019-recover-fund/contracts/BridgeTrackingRecoveryLogic.sol";

import { SlashIndicator } from "@ronin/contracts/ronin/slash-indicator/SlashIndicator.sol";
import { Staking, IStaking } from "@ronin/contracts/ronin/staking/Staking.sol";
import { Profile } from "@ronin/contracts/ronin/profile/Profile.sol";
import { Maintenance } from "@ronin/contracts/ronin/Maintenance.sol";
import { RoninValidatorSet } from "@ronin/contracts/ronin/validator/RoninValidatorSet.sol";
import { StakingVesting } from "@ronin/contracts/ronin/StakingVesting.sol";
import { FastFinalityTracking } from "@ronin/contracts/ronin/fast-finality/FastFinalityTracking.sol";

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

import "./ArrayReplaceLib.sol";
import "./20240220_Base_Miko_Hardfork.s.sol";

contract Proposal__20240220_MikoHardfork_After is Proposal__Base_20240220_MikoHardfork {
  using LibProxy for *;
  using StdStyle for *;
  using ArrayReplaceLib for *;

  uint256 _lockedAmount;
  uint256 _recoveredFund;

  /**
   * See `README.md`
   */
  function run() public virtual override onlyOn(DefaultNetwork.RoninMainnet.key()) {
    Proposal__Base_20240220_MikoHardfork.run();

    _run_unchained();
  }

  function _run_unchained() internal virtual {
    // [C2.] The `doctor` will withdraw the locked fund.
    _doctor__recoverFund();

    /*
     * [C3.] The `doctor` will upgrade the Bridge Tracking contract to remove the recovery method.
     * [C4.] The `doctor` will transfer admin to BridgeManager.
     * [C5.] The `doctor` will transfer all fund to Andy's trezor.
     */
    _doctor__rollbackBridgeTracking();
  }

  function _doctor__recoverFund() internal {
    console2.log("\n---- Recover fund to doctor's account ---".magenta());

    address doctor = ADMIN_TMP_BRIDGE_TRACKING;
    _lockedAmount = address(DEPRECATED_BRIDGE_REWARD).balance;

    // Step 3
    bool shouldPrankOnly = CONFIG.isBroadcastDisable();

    if (shouldPrankOnly) {
      vm.prank(DEPLOYER);
    } else {
      vm.broadcast(DEPLOYER);
    }
    address logic = address(new BridgeTrackingRecoveryLogic());

    if (shouldPrankOnly) {
      vm.prank(doctor);
    } else {
      vm.broadcast(doctor);
    }
    TransparentUpgradeableProxyV2(payable((bridgeTracking))).upgradeTo(logic);

    if (shouldPrankOnly) {
      vm.prank(doctor);
    } else {
      vm.broadcast(doctor);
    }
    TransparentUpgradeableProxyV2(payable((bridgeTracking))).functionDelegateCall(
      abi.encodeCall(BridgeTrackingRecoveryLogic.recoverFund, ())
    );

    uint256 balanceAfter = doctor.balance;
    console.log("Doctor's balance before:", balanceBefore);
    console.log("Doctor's balance after: ", balanceAfter);
    _recoveredFund = balanceAfter - balanceBefore;
    console.log("recoveredFund:          ".green().bold(), _recoveredFund);
    console.log("stuckFund    :          ".red().bold(), _lockedAmount - _recoveredFund);
  }

  function _doctor__rollbackBridgeTracking() internal {
    console2.log("\n---- Transfer to Andy's account ---".magenta());

    address doctor = ADMIN_TMP_BRIDGE_TRACKING;
    bool shouldPrankOnly = CONFIG.isBroadcastDisable();

    if (shouldPrankOnly) {
      vm.prank(DEPLOYER);
    } else {
      vm.broadcast(DEPLOYER);
    }
    address logic = address(new BridgeTracking());

    if (shouldPrankOnly) {
      vm.prank(doctor);
    } else {
      vm.broadcast(doctor);
    }
    TransparentUpgradeableProxyV2(payable((bridgeTracking))).upgradeTo(logic);

    if (shouldPrankOnly) {
      vm.prank(doctor);
    } else {
      vm.broadcast(doctor);
    }
    TransparentUpgradeableProxyV2(payable((bridgeTracking))).changeAdmin(roninBridgeManager);

    uint256 andyBalanceBefore = ANDY_TREZOR.balance;

    if (shouldPrankOnly) {
      vm.prank(doctor);
    } else {
      vm.broadcast(doctor);
    }
    payable(ANDY_TREZOR).transfer(_recoveredFund); // Excludes 20 RON of BAO_EOA

    uint256 andyBalanceAfter = ANDY_TREZOR.balance;
    uint256 andyBalanceChange = andyBalanceAfter - andyBalanceBefore;
    console2.log("Recovered fund:         ".green().bold(), _recoveredFund, "wei");
    console2.log("Andy's balance change: +", andyBalanceChange, "wei");
    console2.log("Andy's balance before:  ", andyBalanceBefore, "wei");
    console2.log("Andy's balance after:   ", andyBalanceAfter, "wei");
    assertTrue(andyBalanceChange > 0, "Error Andy Balance not change!!!");
    assertTrue(andyBalanceChange == _recoveredFund, "Error Andy Balance not equal recovered fund!!!");
  }
}
