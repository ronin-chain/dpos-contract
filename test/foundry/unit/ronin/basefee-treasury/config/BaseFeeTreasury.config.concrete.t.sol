// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { LibSharedAddress } from "@fdk/libraries/LibSharedAddress.sol";
import { BaseFeeTreasury_Base_Test } from "test/foundry/unit/ronin/basefee-treasury/BaseFeeTreasury.base.t.sol";

import { ISharedArgument } from "script/interfaces/ISharedArgument.sol";

import { Contract } from "script/utils/Contract.sol";
import { TransparentUpgradeableProxyV2 } from "src/extensions/TransparentUpgradeableProxyV2.sol";

import { IBaseFeeTreasury } from "src/interfaces/basefee-treasury/IBaseFeeTreasury.sol";
import { ErrUnauthorized } from "src/utils/CommonErrors.sol";

import { RoleAccess } from "src/utils/RoleAccess.sol";

contract BaseFeeTreasury_Config_Concrete_Test is BaseFeeTreasury_Base_Test {
  error OnlyAdmin();

  function testConcrete_SuccessWhen_DeprecateActiveProposal_setThreshold() external {
    address[] memory cids = validatorSet.getValidatorCandidateIds();
    address admin = profile.getId2Admin(cids[0]);

    vm.warp(block.timestamp + 1 days);

    IBaseFeeTreasury.Proposal memory proposal = this.getValidProposal(cids[0], address(baseFeeTreasury));
    bytes32 hash = baseFeeTreasury.hashProposal(proposal);

    this.propose(admin, proposal, "");

    address gov = vme.getAddressFromCurrentNetwork(Contract.RoninGovernanceAdmin.key());
    this.setThreshold(gov, 1, 2, "");

    assertTrue(baseFeeTreasury.getState(hash) == IBaseFeeTreasury.State.Deprecated, "Proposal should be deprecated");
  }

  function testConcrete_RevertIf_UnauthorizedCaller_setThreshold() external {
    address unauthorized = address(0x1);
    this.setThreshold(unauthorized, 1, 2, abi.encodeWithSelector(OnlyAdmin.selector));

    unauthorized = makeAddr("unauthorized");
    this.setThreshold(unauthorized, 2, 3, abi.encodeWithSelector(OnlyAdmin.selector));
  }

  function testConcrete_RevertIf_SetNumEqualDenom_setThreshold() external {
    address admin = vme.getAddressFromCurrentNetwork(Contract.RoninGovernanceAdmin.key());
    this.setThreshold(admin, 1, 1, abi.encodeWithSelector(IBaseFeeTreasury.ErrInvalidThreshold.selector, 1, 1));
    this.setThreshold(admin, 2, 2, abi.encodeWithSelector(IBaseFeeTreasury.ErrInvalidThreshold.selector, 2, 2));
    this.setThreshold(admin, 0, 0, abi.encodeWithSelector(IBaseFeeTreasury.ErrInvalidThreshold.selector, 0, 0));
  }

  function testConcrete_SuccessWhen_ValidNumAndDenom_setThreshold() external {
    address admin = vme.getAddressFromCurrentNetwork(Contract.RoninGovernanceAdmin.key());
    this.setThreshold(admin, 1, 2, "");
    this.setThreshold(admin, 2, 3, "");
    this.setThreshold(admin, 3, 100, "");
    this.setThreshold(admin, 1, 100, "");
  }

  function testConcrete_RevertIf_NumIsZero_setThreshold() external {
    address admin = vme.getAddressFromCurrentNetwork(Contract.RoninGovernanceAdmin.key());
    this.setThreshold(admin, 0, 2, abi.encodeWithSelector(IBaseFeeTreasury.ErrInvalidThreshold.selector, 0, 2));
    this.setThreshold(admin, 0, 3, abi.encodeWithSelector(IBaseFeeTreasury.ErrInvalidThreshold.selector, 0, 3));
  }

  function testConcrete_RevertIf_DenomIsZero_setThreshold() external {
    address admin = vme.getAddressFromCurrentNetwork(Contract.RoninGovernanceAdmin.key());
    this.setThreshold(admin, 1, 0, abi.encodeWithSelector(IBaseFeeTreasury.ErrInvalidThreshold.selector, 1, 0));
    this.setThreshold(admin, 0, 0, abi.encodeWithSelector(IBaseFeeTreasury.ErrInvalidThreshold.selector, 0, 0));
  }

  function testConcrete_RevertIf_NumIsGreaterThanDenom_setThreshold() external {
    address admin = vme.getAddressFromCurrentNetwork(Contract.RoninGovernanceAdmin.key());
    this.setThreshold(admin, 2, 1, abi.encodeWithSelector(IBaseFeeTreasury.ErrInvalidThreshold.selector, 2, 1));
    this.setThreshold(admin, 3, 2, abi.encodeWithSelector(IBaseFeeTreasury.ErrInvalidThreshold.selector, 3, 2));
  }
}
