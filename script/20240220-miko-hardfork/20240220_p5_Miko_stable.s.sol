// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStaking } from "@ronin/contracts/interfaces/staking/IStaking.sol";
import { IProfile } from "@ronin/contracts/interfaces/IProfile.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

import { Proposal__Base_20240220_MikoHardfork } from "./20240220_Base_Miko_Hardfork.s.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";

contract Proposal__20240220_MikoHardfork_Stable is Proposal__Base_20240220_MikoHardfork {
  /**
   * See `README.md`
   */
  function run() public virtual override onlyOn(DefaultNetwork.RoninMainnet.key()) {
    Proposal__Base_20240220_MikoHardfork.run();

    _run_unchained();
  }

  function _run_unchained() internal virtual {
    _migrator__disableMigrate();
  }

  function _migrator__disableMigrate() internal {
    bool shouldPrankOnly = vme.isPostChecking();
    if (shouldPrankOnly) {
      vm.prank(STAKING_MIGRATOR);
    } else {
      vm.broadcast(STAKING_MIGRATOR);
    }
    stakingContract.disableMigrateWasAdmin();

    address[] memory poolIds = new address[](1);
    address[] memory admins = new address[](1);
    bool[] memory flags = new bool[](1);

    vm.startPrank(STAKING_MIGRATOR);
    vm.expectRevert(abi.encodeWithSelector(IStaking.ErrMigrateWasAdminAlreadyDone.selector));
    stakingContract.migrateWasAdmin(poolIds, admins, flags);
    vm.stopPrank();
  }
}
