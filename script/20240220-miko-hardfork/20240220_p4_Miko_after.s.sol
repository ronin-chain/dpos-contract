// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StdStyle } from "forge-std/StdStyle.sol";
import { BridgeTrackingRecoveryLogic } from "../20231019-recover-fund/contracts/BridgeTrackingRecoveryLogic.sol";
import { Proposal__Base_20240220_MikoHardfork } from "./20240220_Base_Miko_Hardfork.s.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { console } from "forge-std/console.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin-v4/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ITransparentUpgradeableProxyV2 } from
  "src/interfaces/extensions/ITransparentUpgradeableProxyV2.sol";

contract Proposal__20240220_MikoHardfork_After is Proposal__Base_20240220_MikoHardfork {
  using StdStyle for *;

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
    console.log("\n---- Recover fund to doctor's account ---".magenta());

    address doctor = ADMIN_TMP_BRIDGE_TRACKING;
    balanceBefore = doctor.balance;
    _lockedAmount = address(DEPRECATED_BRIDGE_REWARD).balance;

    // Step 3
    bool shouldPrankOnly = vme.isPostChecking();

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
    TransparentUpgradeableProxy(payable((bridgeTracking))).upgradeTo(logic);

    if (shouldPrankOnly) {
      vm.prank(doctor);
    } else {
      vm.broadcast(doctor);
    }
    ITransparentUpgradeableProxyV2(bridgeTracking).functionDelegateCall(
      abi.encodeCall(BridgeTrackingRecoveryLogic.recoverFund, ())
    );

    uint256 balanceAfter = doctor.balance;
    console.log("Doctor", doctor);
    console.log("Doctor's balance before:", balanceBefore);
    console.log("Doctor's balance after: ", balanceAfter);
    _recoveredFund = balanceAfter - balanceBefore;
    console.log("lockedAmount:           ".green().bold(), _lockedAmount);
    console.log("recoveredFund:          ".green().bold(), _recoveredFund);

    if (_lockedAmount > _recoveredFund) {
      console.log("stuckFund    :          ".red().bold(), _lockedAmount - _recoveredFund);
    }

    if (_lockedAmount <= _recoveredFund) {
      console.log("stuckFund  ??:          ".red().bold(), _recoveredFund - _lockedAmount);
    }
  }

  function _doctor__rollbackBridgeTracking() internal {
    console.log("\n---- Transfer to Andy's account ---".magenta());
    console.log("Andy", ANDY_TREZOR);

    address doctor = ADMIN_TMP_BRIDGE_TRACKING;
    bool shouldPrankOnly = vme.isPostChecking();

    if (shouldPrankOnly) {
      vm.prank(DEPLOYER);
    } else {
      vm.broadcast(DEPLOYER);
    }
    address logic = address(makeAddr("new BridgeTracking()")); // logic is removed from this repo

    if (shouldPrankOnly) {
      vm.prank(doctor);
    } else {
      vm.broadcast(doctor);
    }
    TransparentUpgradeableProxy(payable((bridgeTracking))).upgradeTo(logic);

    if (shouldPrankOnly) {
      vm.prank(doctor);
    } else {
      vm.broadcast(doctor);
    }
    TransparentUpgradeableProxy(payable((bridgeTracking))).changeAdmin(roninBridgeManager);

    uint256 andyBalanceBefore = ANDY_TREZOR.balance;

    if (shouldPrankOnly) {
      vm.prank(doctor);
    } else {
      vm.broadcast(doctor);
    }
    payable(ANDY_TREZOR).transfer(_recoveredFund); // Excludes 20 RON of BAO_EOA

    uint256 andyBalanceAfter = ANDY_TREZOR.balance;
    uint256 andyBalanceChange = andyBalanceAfter - andyBalanceBefore;
    console.log("Recovered fund:         ".green().bold(), _recoveredFund, "wei");
    console.log("Andy's balance change: +", andyBalanceChange, "wei");
    console.log("Andy's balance before:  ", andyBalanceBefore, "wei");
    console.log("Andy's balance after:   ", andyBalanceAfter, "wei");
    assertTrue(andyBalanceChange > 0, "Error Andy Balance not change!!!");
    assertTrue(andyBalanceChange == _recoveredFund, "Error Andy Balance not equal recovered fund!!!");
  }
}
