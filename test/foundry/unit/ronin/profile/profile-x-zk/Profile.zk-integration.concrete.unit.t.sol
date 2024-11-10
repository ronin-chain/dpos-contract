// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17 <0.9.0;

import { RoleAccess } from "src/utils/RoleAccess.sol";

import "../Profile.base.unit.t.sol";

contract Profile_ZkIntegration_Concrete_Unit_Test is Profile_Base_Unit_Test {
  address internal _cid1 = makeAddr("cid-1");
  address internal _cid2 = makeAddr("cid-2");

  function setUp() public virtual override {
    super.setUp();

    // Prank setup candidate #1
    MockValidatorSet.ValidatorCandidate memory candidate1;
    candidate1.__shadowedAdmin = makeAddr("admin-1");
    candidate1.__shadowedConsensus = TConsensus.wrap(makeAddr("consensus-1"));
    candidate1.__shadowedTreasury = payable(makeAddr("treasury-1"));
    candidate1.commissionRate = 100;
    _validatorSet.exposed_setValidatorCandidate(_cid1, candidate1);
    IProfile.CandidateProfile memory profile1;
    profile1.id = _cid1;
    profile1.consensus = TConsensus.wrap(_cid1);
    profile1.admin = candidate1.__shadowedAdmin;
    profile1.treasury = candidate1.__shadowedTreasury;
    _profile.exposed_addNewProfile(profile1);

    // Prank setup candidate #2
    MockValidatorSet.ValidatorCandidate memory candidate2;
    candidate2.__shadowedAdmin = _validatorAdmin;
    candidate2.__shadowedConsensus = TConsensus.wrap(makeAddr("consensus-2"));
    candidate2.__shadowedTreasury = payable(makeAddr("treasury-2"));
    candidate2.commissionRate = 100;
    candidate2.revokingTimestamp = 0;
    candidate2.topupDeadline = 0;
    _validatorSet.exposed_setValidatorCandidate(_cid2, candidate2);
    IProfile.CandidateProfile memory profile2;
    profile2.id = _cid2;
    profile2.consensus = TConsensus.wrap(_cid2);
    profile2.admin = candidate2.__shadowedAdmin;
    profile2.treasury = candidate2.__shadowedTreasury;
    _profile.exposed_addNewProfile(profile2);
  }

  function testConcrete_execCreateRollup() external {
    uint32 rollupId = 1;

    vm.expectEmit(address(_profile));
    emit IProfile.AggregatorChanged(_cid1, _cid1);
    vm.expectEmit(address(_profile));
    emit IProfile.SequencerChanged(_cid1, _cid1);
    vm.expectEmit(address(_profile));
    emit IProfile.RollupCreated(_cid1, rollupId);

    vm.prank(_zkRollupManager);
    _profile.execCreateRollup(_cid1, rollupId);

    assertEq(_profile.getId2Profile(_cid1).rollupId, rollupId, "rollupId should be set");
    assertEq(_profile.getId2Profile(_cid1).aggregator, _cid1, "aggregator should be set");
    assertEq(_profile.getId2Profile(_cid1).sequencer, _cid1, "sequencer should be set");
  }

  function testConcrete_RevertIf_OnRenunciation_execCreateRollup() external {
    uint32 rollupId = 1;

    _validatorSet.exposed_setRenounceStatus(_cid1, block.timestamp + 1 days);

    vm.expectRevert(abi.encodeWithSelector(IProfile.ErrValidatorOnRenunciation.selector, _cid1));
    vm.prank(_zkRollupManager);
    _profile.execCreateRollup(_cid1, rollupId);
  }

  function testConcrete_RevertIf_RegisterRollupIdTwice() external {
    uint32 rollupId = 1;

    vm.prank(_zkRollupManager);
    _profile.execCreateRollup(_cid1, rollupId);

    vm.expectRevert(abi.encodeWithSelector(IProfile.ErrRollupIdAlreadyRegistered.selector, rollupId));
    vm.prank(_zkRollupManager);
    _profile.execCreateRollup(_cid1, rollupId);
  }

  function testConcrete_execCreateRollup_ForCid1AndCid2() external {
    uint32 rollupId1 = 1;
    uint32 rollupId2 = 2;

    vm.expectEmit(address(_profile));
    emit IProfile.AggregatorChanged(_cid1, _cid1);
    vm.expectEmit(address(_profile));
    emit IProfile.SequencerChanged(_cid1, _cid1);
    vm.expectEmit(address(_profile));
    emit IProfile.RollupCreated(_cid1, rollupId1);

    vm.prank(_zkRollupManager);
    _profile.execCreateRollup(_cid1, rollupId1);

    assertEq(_profile.getId2Profile(_cid1).rollupId, rollupId1, "rollupId should be set");
    assertEq(_profile.getId2Profile(_cid1).aggregator, _cid1, "aggregator should be set");
    assertEq(_profile.getId2Profile(_cid1).sequencer, _cid1, "sequencer should be set");

    vm.expectEmit(address(_profile));
    emit IProfile.AggregatorChanged(_cid2, _cid2);
    vm.expectEmit(address(_profile));
    emit IProfile.SequencerChanged(_cid2, _cid2);
    vm.expectEmit(address(_profile));
    emit IProfile.RollupCreated(_cid2, rollupId2);

    vm.prank(_zkRollupManager);
    _profile.execCreateRollup(_cid2, rollupId2);

    assertEq(_profile.getId2Profile(_cid2).rollupId, rollupId2, "rollupId should be set");
    assertEq(_profile.getId2Profile(_cid2).aggregator, _cid2, "aggregator should be set");
    assertEq(_profile.getId2Profile(_cid2).sequencer, _cid2, "sequencer should be set");
  }

  function testConcrete_RevertIf_RegisterRollupIdZero() external {
    uint32 rollupId = 0;

    vm.expectRevert(abi.encodeWithSelector(IProfile.ErrZeroRollupId.selector, _cid1));
    vm.prank(_zkRollupManager);
    _profile.execCreateRollup(_cid1, rollupId);
  }

  function testConcrete_RevertIf_ChangeSequencer_WhenRollupNotRegistered() external {
    vm.expectRevert(abi.encodeWithSelector(IProfile.ErrZeroRollupId.selector, _cid1));
    vm.prank(_proxyAdmin);
    TransparentUpgradeableProxyV2(payable(address(_profile))).functionDelegateCall(
      abi.encodeCall(IProfile.changeSequencerAddr, (_cid1, makeAddr("new-sequencer")))
    );
  }

  function testConcrete_RevertIf_ChangeSequencer_ToZero() external {
    uint32 rollupId = 1;

    vm.prank(_zkRollupManager);
    _profile.execCreateRollup(_cid1, rollupId);

    vm.expectRevert(abi.encodeWithSelector(IProfile.ErrZeroAddress.selector, RoleAccess.SEQUENCER));
    vm.prank(_proxyAdmin);
    TransparentUpgradeableProxyV2(payable(address(_profile))).functionDelegateCall(
      abi.encodeCall(IProfile.changeSequencerAddr, (_cid1, address(0)))
    );
  }

  function testConcrete_RevertIf_ChangeAggregator_ToZero() external {
    uint32 rollupId = 1;

    vm.prank(_zkRollupManager);
    _profile.execCreateRollup(_cid1, rollupId);

    vm.expectRevert(abi.encodeWithSelector(IProfile.ErrZeroAddress.selector, RoleAccess.AGGREGATOR));
    vm.prank(_proxyAdmin);
    TransparentUpgradeableProxyV2(payable(address(_profile))).functionDelegateCall(
      abi.encodeCall(IProfile.changeAggregatorAddr, (_cid1, address(0)))
    );
  }

  function testConcrete_RevertIf_ChangeAggregator_WhenRollupNotRegistered() external {
    vm.expectRevert(abi.encodeWithSelector(IProfile.ErrZeroRollupId.selector, _cid1));
    vm.prank(_proxyAdmin);
    TransparentUpgradeableProxyV2(payable(address(_profile))).functionDelegateCall(
      abi.encodeCall(IProfile.changeAggregatorAddr, (_cid1, makeAddr("new-aggregator")))
    );
  }

  function testConcrete_RevertIf_ChangeAggregator_DuplicateToAnotherCid() external {
    uint32 rollupId = 1;

    vm.prank(_zkRollupManager);
    _profile.execCreateRollup(_cid1, rollupId);

    vm.expectRevert(abi.encodeWithSelector(IProfile.ErrDuplicatedInfo.selector, RoleAccess.AGGREGATOR, _cid2));
    vm.prank(_proxyAdmin);
    TransparentUpgradeableProxyV2(payable(address(_profile))).functionDelegateCall(
      abi.encodeCall(IProfile.changeAggregatorAddr, (_cid1, _cid2))
    );
  }

  function testConcrete_ReVertIf_ChangeSequencer_DuplicateToAnotherCid() external {
    uint32 rollupId = 1;

    vm.prank(_zkRollupManager);
    _profile.execCreateRollup(_cid1, rollupId);

    vm.expectRevert(abi.encodeWithSelector(IProfile.ErrDuplicatedInfo.selector, RoleAccess.SEQUENCER, _cid2));
    vm.prank(_proxyAdmin);
    TransparentUpgradeableProxyV2(payable(address(_profile))).functionDelegateCall(
      abi.encodeCall(IProfile.changeSequencerAddr, (_cid1, _cid2))
    );
  }

  function testConcrete_RevertIf_ChangeAggregator_ReUpdate() external {
    uint32 rollupId = 1;

    vm.prank(_zkRollupManager);
    _profile.execCreateRollup(_cid1, rollupId);

    vm.expectRevert(abi.encodeWithSelector(IProfile.ErrDuplicatedInfo.selector, RoleAccess.AGGREGATOR, _cid1));
    vm.prank(_proxyAdmin);
    TransparentUpgradeableProxyV2(payable(address(_profile))).functionDelegateCall(
      abi.encodeCall(IProfile.changeAggregatorAddr, (_cid1, _cid1))
    );
  }

  function testConcrete_RevertIf_ChangeSequencer_ReUpdate() external {
    uint32 rollupId = 1;

    vm.prank(_zkRollupManager);
    _profile.execCreateRollup(_cid1, rollupId);

    vm.expectRevert(abi.encodeWithSelector(IProfile.ErrDuplicatedInfo.selector, RoleAccess.SEQUENCER, _cid1));
    vm.prank(_proxyAdmin);
    TransparentUpgradeableProxyV2(payable(address(_profile))).functionDelegateCall(
      abi.encodeCall(IProfile.changeSequencerAddr, (_cid1, _cid1))
    );
  }

  function testConcrete_RevertIf_ChangeAggregator_DuplicateWithAnotherAggregator() external {
    uint32 rollupId1 = 1;
    uint32 rollupId2 = 2;

    vm.prank(_zkRollupManager);
    _profile.execCreateRollup(_cid1, rollupId1);

    address newAggregator1 = makeAddr("new-aggregator-1");
    vm.prank(_proxyAdmin);
    TransparentUpgradeableProxyV2(payable(address(_profile))).functionDelegateCall(
      abi.encodeCall(IProfile.changeAggregatorAddr, (_cid1, newAggregator1))
    );

    vm.prank(_zkRollupManager);
    _profile.execCreateRollup(_cid2, rollupId2);

    vm.expectRevert(abi.encodeWithSelector(IProfile.ErrDuplicatedInfo.selector, RoleAccess.AGGREGATOR, newAggregator1));
    vm.prank(_proxyAdmin);
    TransparentUpgradeableProxyV2(payable(address(_profile))).functionDelegateCall(
      abi.encodeCall(IProfile.changeAggregatorAddr, (_cid2, newAggregator1))
    );
  }

  function testConcrete_RevertIf_ChangeSequencer_DuplicateWithAnotherSequencer() external {
    uint32 rollupId1 = 1;
    uint32 rollupId2 = 2;

    vm.prank(_zkRollupManager);
    _profile.execCreateRollup(_cid1, rollupId1);

    address newSequencer1 = makeAddr("new-sequencer-1");
    vm.prank(_proxyAdmin);
    TransparentUpgradeableProxyV2(payable(address(_profile))).functionDelegateCall(
      abi.encodeCall(IProfile.changeSequencerAddr, (_cid1, newSequencer1))
    );

    vm.prank(_zkRollupManager);
    _profile.execCreateRollup(_cid2, rollupId2);

    vm.expectRevert(abi.encodeWithSelector(IProfile.ErrDuplicatedInfo.selector, RoleAccess.SEQUENCER, newSequencer1));
    vm.prank(_proxyAdmin);
    TransparentUpgradeableProxyV2(payable(address(_profile))).functionDelegateCall(
      abi.encodeCall(IProfile.changeSequencerAddr, (_cid2, newSequencer1))
    );
  }
}
