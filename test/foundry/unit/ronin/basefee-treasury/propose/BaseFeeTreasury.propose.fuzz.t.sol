// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { console } from "forge-std/console.sol";

import { BaseFeeTreasury_Base_Test } from "test/foundry/unit/ronin/basefee-treasury/BaseFeeTreasury.base.t.sol";

import { LibApplyCandidate } from "script/shared/libraries/LibApplyCandidate.sol";
import { LibWrapUpEpoch } from "script/shared/libraries/LibWrapUpEpoch.sol";

import { IBaseFeeTreasury } from "src/interfaces/basefee-treasury/IBaseFeeTreasury.sol";
import { ICandidateManager } from "src/interfaces/validator/ICandidateManager.sol";
import { TConsensus } from "src/udvts/Types.sol";

import { ErrEmptyArray, ErrLengthMismatch, ErrUnauthorized } from "src/utils/CommonErrors.sol";
import { RoleAccess } from "src/utils/RoleAccess.sol";

contract BaseFeeTreasury_Propose_Fuzz_Test is BaseFeeTreasury_Base_Test {
  function testFuzz_propose(bool correctSender, address by, IBaseFeeTreasury.Proposal memory p) external {
    vm.warp(block.timestamp + 1 days);
    if (correctSender) {
      uint256 idx = vm.unixTime();
      address[] memory cids = validatorSet.getValidatorCandidateIds();

      p.proposer = cids[idx % cids.length];
      by = profile.getId2Admin(p.proposer);
    }

    try this.expectRevertPropose(by, p) returns (bool shouldRevert) {
      if (shouldRevert) vm.expectRevert();
    } catch {
      vm.expectRevert();
    }

    vm.prank(by);
    baseFeeTreasury.propose(p);
  }

  function expectRevertPropose(
    address by,
    IBaseFeeTreasury.Proposal memory p
  ) external view returns (bool shouldRevert) {
    if (p.executor == address(0x0)) return true;
    if (profile.getId2Admin(p.proposer) != by) return true;
    if (p.expiry < block.timestamp + baseFeeTreasury.MIN_PROPOSAL_DURATION()) return true;
    if (p.nonce != baseFeeTreasury.getGlobalNonce()) return true;
    if (!(p.amounts.length == p.recipients.length && p.amounts.length == p.callDatas.length)) return true;
    if (p.amounts.length == 0) return true;
    if (hasNull(p.amounts)) return true;
    if (hasNull(p.recipients)) return true;
    if (contain(p.recipients, address(baseFeeTreasury))) return true;
  }
}
