// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TContract } from "@fdk/types/Types.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
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

contract Proposal__20240220_MikoHardfork_Before is Proposal__Base_20240220_MikoHardfork {
  using LibProxy for *;
  using StdStyle for *;
  using ArrayReplaceLib for *;

  /**
   * See `README.md`
   */
  function run() public virtual override onlyOn(DefaultNetwork.RoninMainnet.key()) {
    Proposal__Base_20240220_MikoHardfork.run();

    _run_unchained();
  }

  function _run_unchained() internal virtual {
    _eoa__changeAdminToGA();
  }

  function _eoa__changeAdminToGA() internal {
    bool shouldPrankOnly = vme.isPostChecking();

    if (shouldPrankOnly) {
      vm.prank(BAO_EOA);
    } else {
      vm.broadcast(BAO_EOA);
    }
    TransparentUpgradeableProxy(payable(address(profileContract))).changeAdmin(address(roninGovernanceAdmin));

    if (shouldPrankOnly) {
      vm.prank(BAO_EOA);
    } else {
      vm.broadcast(BAO_EOA);
    }
    TransparentUpgradeableProxy(payable(address(fastFinalityTrackingContract))).changeAdmin(
      address(roninGovernanceAdmin)
    );
  }
}
