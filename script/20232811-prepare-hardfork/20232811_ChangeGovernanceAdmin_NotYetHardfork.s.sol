// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Migration__20232811_ChangeGovernanceAdmin_Common } from "./20232811_ChangeGovernanceAdmin_Common.s.sol";
import { Contract } from "script/utils/Contract.sol";

contract Migration__20232811_ChangeGovernanceAdmin_NotYetHardfork is Migration__20232811_ChangeGovernanceAdmin_Common {
  bytes32 constant $_IMPL_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

  function __node_hardfork_hook() internal override {
    // Get current broken Ronin Governance Admin
    __roninGovernanceAdmin = loadContract(Contract.RoninGovernanceAdmin.key());

    // Deploy new Ronin Governance Admin
    __trustedOrg = loadContract(Contract.RoninTrustedOrganization.key());

    // Deploy temporary Ronin Trusted Organization
    address tempTrustedOrgLogic = _deployLogic(Contract.TemporalRoninTrustedOrganization.key());
    vm.makePersistent(address(tempTrustedOrgLogic));

    // Cheat storage slot of impl in Trusted Org Proxy
    vm.store(address(__trustedOrg), bytes32($_IMPL_SLOT), bytes32(uint256(uint160(tempTrustedOrgLogic))));
  }
}
