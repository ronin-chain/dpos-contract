// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { LibSharedAddress } from "@fdk/libraries/LibSharedAddress.sol";
import { Test, console } from "forge-std/Test.sol";

import { DeployDPoS } from "script/deploy-dpos/DeployDPoS.s.sol";
import { ISharedArgument } from "script/interfaces/ISharedArgument.sol";

import { LibPrecompile } from "script/shared/libraries/LibPrecompile.sol";
import { Contract } from "script/utils/Contract.sol";
import { TransparentUpgradeableProxyV2 } from "src/extensions/TransparentUpgradeableProxyV2.sol";

import { IBaseFeeTreasury } from "src/interfaces/basefee-treasury/IBaseFeeTreasury.sol";
import { ICandidateManager } from "src/interfaces/validator/ICandidateManager.sol";
import { IRoninValidatorSet } from "src/interfaces/validator/IRoninValidatorSet.sol";
import { Maintenance } from "src/ronin/Maintenance.sol";
import { IProfile, Profile, TConsensus } from "src/ronin/profile/Profile.sol";
import { IStaking, Staking } from "src/ronin/staking/Staking.sol";
import { ErrUnauthorized } from "src/utils/CommonErrors.sol";

import { RoleAccess } from "src/utils/RoleAccess.sol";

contract BaseFeeTreasury_Base_Test is Test {
  address internal coinbase;
  Profile internal profile;
  Staking internal staking;
  Maintenance internal maintenance;
  IBaseFeeTreasury internal baseFeeTreasury;
  IRoninValidatorSet internal validatorSet;
  ISharedArgument internal vme = ISharedArgument(LibSharedAddress.VME);

  function setUp() public virtual {
    coinbase = makeAddr("coinbase");
    vm.coinbase(coinbase);

    vm.roll(block.number + 1000);
    vm.warp(block.timestamp + 3000);

    DeployDPoS dposDeployHelper = new DeployDPoS();
    dposDeployHelper.setUp();
    dposDeployHelper.run();
    LibPrecompile.deployPrecompile();
    dposDeployHelper.cheatSetUpValidators();

    profile = Profile(vme.getAddressFromCurrentNetwork(Contract.Profile.key()));
    staking = Staking(vme.getAddressFromCurrentNetwork(Contract.Staking.key()));
    maintenance = Maintenance(vme.getAddressFromCurrentNetwork(Contract.Maintenance.key()));
    validatorSet = IRoninValidatorSet(vme.getAddressFromCurrentNetwork(Contract.RoninValidatorSet.key()));
    baseFeeTreasury = IBaseFeeTreasury(vme.getAddressFromCurrentNetwork(Contract.RoninBaseFeeTreasury.key()));

    // Exclude Contract For Invariant
    excludeContract(address(dposDeployHelper));
    excludeContract(LibSharedAddress.VM);
    excludeContract(LibSharedAddress.VME);
    excludeContract(LibSharedAddress.ARTIFACT_FACTORY);

    // Exclude Sender For Invariant
    excludeSender(address(dposDeployHelper));
    excludeSender(LibSharedAddress.VM);
    excludeSender(LibSharedAddress.VME);
    excludeSender(LibSharedAddress.ARTIFACT_FACTORY);

    excludeContractForInvariants();
  }

  function excludeContractForInvariants() public {
    try vme.getUserDefinedConfig("system-contracts") returns (bytes memory ret) {
      address[] memory sysContracts = abi.decode(ret, (address[]));
      console.log("System-contracts found: ", sysContracts.length);

      for (uint256 i = 0; i < sysContracts.length; i++) {
        excludeContract(sysContracts[i]);
        excludeSender(sysContracts[i]);
      }
    } catch {
      console.log("No system-contracts found");
    }
  }

  function getValidProposal(
    address proposer,
    address executor
  ) external view returns (IBaseFeeTreasury.Proposal memory proposal) {
    proposal.proposer = proposer;
    proposal.executor = executor;
    proposal.nonce = baseFeeTreasury.getGlobalNonce();
    proposal.expiry = uint40(block.timestamp + baseFeeTreasury.MIN_PROPOSAL_DURATION());
    proposal.recipients = new address[](2);
    proposal.amounts = new uint96[](2);
    proposal.callDatas = new bytes[](2);

    proposal.recipients[0] = address(0x1);
    proposal.recipients[1] = address(0x2);

    proposal.amounts[0] = 1;
    proposal.amounts[1] = 2;
  }

  function execute(address by, bytes32 hash, bytes memory revertData) external {
    IBaseFeeTreasury.State prvState = baseFeeTreasury.getState(hash);
    assertNotContain(baseFeeTreasury.getPendingProposals(), hash);

    if (revertData.length == 0) {
      vm.expectEmit(address(baseFeeTreasury));
      emit IBaseFeeTreasury.ProposalExecuted(by, hash);
    } else {
      vm.expectRevert(revertData);
    }

    vm.prank(by);
    baseFeeTreasury.execute(hash);

    if (revertData.length != 0) return;

    assertTrue(baseFeeTreasury.getState(hash) == IBaseFeeTreasury.State.Executed, "state is not set");
    assertNotContain(baseFeeTreasury.getPendingProposals(), hash);
  }

  function cancel(address by, bytes32 hash, bytes memory revertData) external {
    if (revertData.length == 0) {
      vm.expectEmit(address(baseFeeTreasury));
      emit IBaseFeeTreasury.ProposalCancelled(by, hash);
    } else {
      vm.expectRevert(revertData);
    }

    vm.prank(by);
    baseFeeTreasury.cancel(hash);

    if (revertData.length != 0) return;

    assertTrue(baseFeeTreasury.getState(hash) == IBaseFeeTreasury.State.Cancelled, "state is not set");
    assertNotContain(baseFeeTreasury.getPendingProposals(), hash);
  }

  function vote(
    address by,
    address cid,
    bytes32 hash,
    IBaseFeeTreasury.Vote voteSide,
    bytes memory revertData
  ) external {
    IBaseFeeTreasury.VotePower memory prvVotePow = baseFeeTreasury.getCurrentVotePower(hash);
    uint256 expectedCidVotePower = baseFeeTreasury.getSnapshotVotePowerById(hash, cid);

    if (revertData.length == 0) {
      address[] memory cids = new address[](1);
      cids[0] = cid;
      uint256[] memory weights = staking.getManySelfStakingsById(cids);
      expectedCidVotePower = weights[0] / 1 ether;
      vm.expectEmit(address(baseFeeTreasury));
      emit IBaseFeeTreasury.Voted(by, cid, hash, voteSide, expectedCidVotePower);
    } else {
      vm.expectRevert(revertData);
    }

    vm.prank(by);
    baseFeeTreasury.vote(cid, hash, voteSide);

    if (revertData.length != 0) return;

    assertTrue(expectedCidVotePower != 0, "voting power is zero");
    assertTrue(baseFeeTreasury.getVote(hash, cid) == voteSide, "voteSide is not set");

    IBaseFeeTreasury.VotePower memory currVotePow = baseFeeTreasury.getCurrentVotePower(hash);

    if (voteSide == IBaseFeeTreasury.Vote.For) {
      assertEq(currVotePow.vFor, prvVotePow.vFor + expectedCidVotePower, "current voteSide power is not updated");
    } else {
      assertEq(
        currVotePow.vAgainst, prvVotePow.vAgainst + expectedCidVotePower, "current voteSide power must not be updated"
      );
    }
  }

  function setThreshold(address by, uint8 num, uint8 denom, bytes memory revertData) external {
    uint256 prvGlobalNonce = baseFeeTreasury.getGlobalNonce();

    if (revertData.length == 0) {
      vm.expectEmit(address(baseFeeTreasury));
      emit IBaseFeeTreasury.ThresholdUpdated(by, num, denom);
    } else {
      vm.expectRevert(revertData);
    }

    vm.prank(by);
    TransparentUpgradeableProxyV2(payable(address(baseFeeTreasury))).functionDelegateCall(
      abi.encodeWithSelector(IBaseFeeTreasury.setThreshold.selector, num, denom)
    );

    if (revertData.length != 0) return;

    IBaseFeeTreasury.Threshold memory threshold = baseFeeTreasury.getThreshold();

    assertEq(threshold.num, num, "num is not set");
    assertEq(threshold.denom, denom, "denom is not set");
    assertEq(baseFeeTreasury.getGlobalNonce(), prvGlobalNonce + 1, "global nonce is not incremented");
  }

  function propose(address by, IBaseFeeTreasury.Proposal memory proposal, bytes memory revertData) external {
    bytes32 hash = baseFeeTreasury.hashProposal(proposal);
    uint256 expectedVotePower;
    uint256 pendingCountBefore = baseFeeTreasury.getPendingProposals().length;
    uint256 expectedTotalVotePower;

    if (revertData.length == 0) {
      assertNotContain(baseFeeTreasury.getPendingProposals(), hash);

      address[] memory allCids = validatorSet.getValidatorCandidateIds();
      uint256[] memory allWeights = staking.getManySelfStakingsById(allCids);

      for (uint256 i = 0; i < allCids.length; i++) {
        expectedTotalVotePower += allWeights[i] / 1 ether;
      }

      address[] memory cids = new address[](1);
      cids[0] = proposal.proposer;
      uint256[] memory weights = staking.getManySelfStakingsById(cids);
      expectedVotePower = weights[0] / 1 ether;
      vm.expectEmit(address(baseFeeTreasury));
      emit IBaseFeeTreasury.ProposalCreated(by, proposal.proposer, hash, proposal, uint40(block.timestamp));
      vm.expectEmit(address(baseFeeTreasury));
      emit IBaseFeeTreasury.Voted(by, proposal.proposer, hash, IBaseFeeTreasury.Vote.For, weights[0] / 1 ether);
    } else {
      vm.expectRevert(revertData);
    }

    vm.prank(by);
    baseFeeTreasury.propose(proposal);

    if (revertData.length != 0) return;

    assertEq(
      expectedTotalVotePower,
      baseFeeTreasury.getMinimumVotePowerToCancel(hash) + baseFeeTreasury.getMinimumVotePowerToPass(hash),
      "total vote power is not set"
    );
    assertContain(baseFeeTreasury.getPendingProposals(), hash);
    assertEq(baseFeeTreasury.getProposalCreatedAt(hash), block.timestamp, "created at is not set");
    assertTrue(baseFeeTreasury.getVote(hash, proposal.proposer) == IBaseFeeTreasury.Vote.For, "vote is not set");
    assertEq(
      baseFeeTreasury.getSnapshotVotePowerById(hash, proposal.proposer), expectedVotePower, "voting power is not set"
    );
    assertEq(baseFeeTreasury.getPendingProposals().length, pendingCountBefore + 1, "pending count is not incremented");
    assertEq(
      keccak256(abi.encode(proposal)), keccak256(abi.encode(baseFeeTreasury.getProposal(hash))), "proposal is not set"
    );
  }

  function assertValidProposalCreation(
    IBaseFeeTreasury.Proposal memory p
  ) internal view {
    assertTrue(p.proposer != address(0), "proposer is not set");
    assertTrue(p.executor != address(0), "executor is not set");
    assertTrue(p.expiry >= block.timestamp + baseFeeTreasury.MIN_PROPOSAL_DURATION(), "expiry is not set");
    assertTrue(p.recipients.length == p.amounts.length && p.recipients.length == p.callDatas.length, "length mismatch");
  }

  function assertContain(bytes32[] memory hashes, bytes32 hash) internal pure {
    for (uint256 i = 0; i < hashes.length; i++) {
      if (hashes[i] == hash) return;
    }

    revert("hash not found");
  }

  function assertNotContain(bytes32[] memory hashes, bytes32 hash) internal pure {
    for (uint256 i = 0; i < hashes.length; i++) {
      if (hashes[i] == hash) revert("hash found");
    }
  }

  function hasNull(
    uint96[] memory a
  ) internal pure returns (bool yes) {
    for (uint256 i = 0; i < a.length; i++) {
      if (a[i] == 0) return true;
    }
  }

  function hasNull(
    address[] memory a
  ) internal pure returns (bool yes) {
    return contain(a, address(0));
  }

  function contain(address[] memory a, address target) internal pure returns (bool yes) {
    for (uint256 i = 0; i < a.length; i++) {
      if (a[i] == target) return true;
    }
  }
}
