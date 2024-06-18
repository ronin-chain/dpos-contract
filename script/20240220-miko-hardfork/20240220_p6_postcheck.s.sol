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

abstract contract Proposal__20240220_PostCheck is Proposal__Base_20240220_MikoHardfork {
  using LibProxy for *;
  using StdStyle for *;
  using ArrayReplaceLib for *;

  function run() public virtual override onlyOn(DefaultNetwork.RoninMainnet.key()) {
    Proposal__Base_20240220_MikoHardfork.run();

    _run_unchained();
  }

  function _run_unchained() internal virtual {
    console2.log("\n== Proposal post checking... ==".magenta().bold());

    _sys_postCheck_profile_all_migrated();
    _sys_postCheck_profile_mainnet_changeConsensusDisabled();
    _sys_postCheck_checkAdminOfBridgeTracking();

    console2.log("\n== Proposal post check finished ==".magenta().bold());
  }

  function _sys_postCheck_profile_all_migrated() internal view {
    (address[] memory poolIds,,) = _sys__parseMigrateData(MIGRATE_DATA_PATH);
    for (uint i; i < poolIds.length; i++) {
      address cid = poolIds[i];
      Profile.CandidateProfile memory profile = profileContract.getId2Profile(cid);
      assertTrue(profile.admin != address(0), "exist profile not migrated");
      assertTrue(profile.treasury != address(0), "exist profile not migrated");
    }
  }

  function _sys_postCheck_profile_mainnet_changeConsensusDisabled() internal {
    vm.expectRevert("Not supported");
    profileContract.changeConsensusAddr(address(0), TConsensus.wrap(address(0)));
  }

  function _sys_postCheck_checkAdminOfBridgeTracking() internal view {
    address actualAdmin = LibProxy.getProxyAdmin(payable(bridgeTracking));
    assertTrue(actualAdmin == 0x5FA49E6CA54a9daa8eCa4F403ADBDE5ee075D84a);
  }
}
