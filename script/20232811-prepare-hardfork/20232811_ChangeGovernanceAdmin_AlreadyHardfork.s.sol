// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./20232811_ChangeGovernanceAdmin_Common.s.sol";
import { Contract } from "script/utils/Contract.sol";

contract Migration__20232811_ChangeGovernanceAdmin_AlreadyHardfork is Migration__20232811_ChangeGovernanceAdmin_Common {
  bytes32 constant $_IMPL_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

  function __node_hardfork_hook() internal override {
    // Get current broken Ronin Governance Admin
    __roninGovernanceAdmin = loadContract(Contract.RoninGovernanceAdmin.key());

    // Cheat storage slot of impl in Trusted Org Proxy
    __trustedOrg = loadContract(Contract.RoninTrustedOrganization.key());

    if (block.chainid == DefaultNetwork.RoninTestnet.chainId()) {
      // vm.store(
      //   address(__trustedOrg),
      //   bytes32($_IMPL_SLOT),
      //   bytes32(uint256(uint160(0x6A51C2B073a6daDBeCAC1A420AFcA7788C81612f)))
      // );
      require(
        address(uint160(uint256(vm.load(address(__trustedOrg), $_IMPL_SLOT))))
          == 0x6A51C2B073a6daDBeCAC1A420AFcA7788C81612f,
        "testnet-shadow / testnet not hardfork yet!!!"
      );
    } else {
      revert("Missing config for 'Temp Trusted Org Logic'");
    }
  }
}
