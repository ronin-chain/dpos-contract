// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TContract } from "@fdk/types/Types.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { Proposal__Base_20240220_MikoHardfork } from "./20240220_Base_Miko_Hardfork.s.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract Proposal__20240220_MikoHardfork_Before is Proposal__Base_20240220_MikoHardfork {
  using LibProxy for *;
  using StdStyle for *;

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
