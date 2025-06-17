// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";

import { TransparentUpgradeableProxyV2 } from "src/extensions/TransparentUpgradeableProxyV2.sol";
import { IStakingVesting, StakingVesting } from "src/ronin/StakingVesting.sol";

import {
  ErrEmptyArray,
  ErrInvalidArguments,
  ErrUnauthorized,
  ErrUnauthorizedCall,
  ErrUnexpectedInternalCall,
  RoleAccess
} from "src/utils/CommonErrors.sol";
import { ContractType } from "src/utils/ContractType.sol";

contract StakingVestingTest is Test {
  StakingVesting internal _stakingVesting;
  TransparentUpgradeableProxyV2 internal _proxy;
  address internal _proxyAdmin = makeAddr("proxyAdmin");
  address internal _validatorContract = makeAddr("validatorContract");
  address internal _admin = makeAddr("admin");
  address internal _user = makeAddr("user");
  IStakingVesting.Reward[] internal _blockRewards;

  event BlockRewardRangeUpdated(address indexed by, uint256 minRewardAmount, uint256 maxRewardAmount);
  event BlockProducerBonusPerBlockUpdated(address indexed by, IStakingVesting.Reward[] blockRewards);
  event FastFinalityRewardPercentageUpdated(uint256 percent);
  event BonusTransferred(
    uint256 indexed blockNumber, address indexed recipient, uint256 blockProducerAmount, uint256 bridgeOperatorAmount
  );
  event BonusTransferFailed(
    uint256 indexed blockNumber,
    address indexed recipient,
    uint256 blockProducerAmount,
    uint256 bridgeOperatorAmount,
    uint256 contractBalance
  );

  function setUp() public {
    address logic = address(new StakingVesting());
    _proxy = new TransparentUpgradeableProxyV2(
      logic, _admin, abi.encodeWithSelector(StakingVesting.initialize.selector, _validatorContract, 0, 0)
    );
    _stakingVesting = StakingVesting(address(_proxy));
    vm.label(address(_stakingVesting), "StakingVesting");

    // Use functionDelegateCall to call initializeV3 as admin
    vm.prank(_admin);
    _proxy.functionDelegateCall(abi.encodeWithSelector(StakingVesting.initializeV3.selector, 8500));

    // From block start to block start+365*28800*3-1, the reward per block is 30,000,000/365/28800.
    // From block start+365*28800*3 to block start+365*28800*4-1, the reward per block is 28,000,000/365/28800.
    // From block start+365*28800*4 to block start+365*28800*5-1, the reward per block is 24,000,000/365/28800.
    // From block start+365*28800*5 to block start+365*28800*6-1, the reward per block is 18,000,000/365/28800.
    // From block start+365*28800*6 to block start+365*28800*7-1, the reward per block is 14,000,000/365/28800.
    // From block start+365*28800*7 to block start+365*28800*8-1, the reward per block is 6,000,000/365/28800.
    // After block start+365*28800*8, the reward per block is 0.
    uint256 start = 1000;
    vm.roll(start);
    IStakingVesting.Reward[] memory blockRewards = new IStakingVesting.Reward[](7);
    blockRewards[0] = IStakingVesting.Reward(uint64(start + 365 * 28_800 * 9), uint64(0 ether)); // After this block, no reward
    blockRewards[1] =
      IStakingVesting.Reward(uint64(start + 365 * 28_800 * 8), uint64(uint256(6_000_000 ether) / 365 / 28_800));
    blockRewards[2] =
      IStakingVesting.Reward(uint64(start + 365 * 28_800 * 7), uint64(uint256(14_000_000 ether) / 365 / 28_800));
    blockRewards[3] =
      IStakingVesting.Reward(uint64(start + 365 * 28_800 * 6), uint64(uint256(18_000_000 ether) / 365 / 28_800));
    blockRewards[4] =
      IStakingVesting.Reward(uint64(start + 365 * 28_800 * 5), uint64(uint256(24_000_000 ether) / 365 / 28_800));
    blockRewards[5] =
      IStakingVesting.Reward(uint64(start + 365 * 28_800 * 4), uint64(uint256(28_000_000 ether) / 365 / 28_800));
    blockRewards[6] =
      IStakingVesting.Reward(uint64(start + 365 * 28_800 * 3), uint64(uint256(30_000_000 ether) / 365 / 28_800));

    vm.prank(_admin);
    _proxy.functionDelegateCall(
      abi.encodeWithSelector(StakingVesting.initializeV5.selector, uint64(0 ether), uint64(10 ether), blockRewards)
    ); // Set min and max reward amounts

    for (uint256 i = 0; i < blockRewards.length; i++) {
      _blockRewards.push(blockRewards[i]);
    }
  }

  function testConcrete_GetBlockProducerBonus() external {
    uint256 blockProducerBonus = _stakingVesting.blockProducerBlockBonus(block.number);
    assertEq(blockProducerBonus, 0 ether, "Block producer bonus should be 0 ether");

    IStakingVesting.Reward memory reward = _blockRewards[_blockRewards.length - 1];
    vm.roll(reward.startBlock);
    blockProducerBonus = _stakingVesting.blockProducerBlockBonus(block.number);
    assertEq(blockProducerBonus, reward.amount, "Block producer bonus should match the last reward amount");

    vm.roll(reward.startBlock + 1);
    blockProducerBonus = _stakingVesting.blockProducerBlockBonus(block.number);
    assertEq(blockProducerBonus, reward.amount, "Block producer bonus should match the last reward amount");

    reward = _blockRewards[_blockRewards.length - 2];
    vm.roll(reward.startBlock);
    blockProducerBonus = _stakingVesting.blockProducerBlockBonus(block.number);
    assertEq(blockProducerBonus, reward.amount, "Block producer bonus should match the second last reward amount");

    vm.roll(reward.startBlock + 1);
    blockProducerBonus = _stakingVesting.blockProducerBlockBonus(block.number);
    assertEq(blockProducerBonus, reward.amount, "Block producer bonus should match the second last reward amount");
    vm.roll(reward.startBlock + 365 * 28_800 * 9); // Roll to a block after the last reward
    blockProducerBonus = _stakingVesting.blockProducerBlockBonus(block.number);
    assertEq(blockProducerBonus, 0 ether, "Block producer bonus should be 0 ether after the last reward");
  }

  function testConcrete_SetBlockRewardRange_Success() external {
    uint64 newMin = 1 ether;
    uint64 newMax = 5 ether;

    vm.expectEmit(true, false, false, true);
    emit BlockRewardRangeUpdated(_admin, newMin, newMax);

    vm.prank(_admin);
    _proxy.functionDelegateCall(abi.encodeWithSelector(StakingVesting.setBlockRewardRange.selector, newMin, newMax));

    (uint64 min, uint64 max) = _stakingVesting.getBlockRewardRange();
    assertEq(min, newMin, "Min reward amount should be updated");
    assertEq(max, newMax, "Max reward amount should be updated");
  }

  function testConcrete_SetBlockRewardRange_RevertWhen_NotAdmin() external {
    vm.prank(_user);
    vm.expectRevert();
    _proxy.functionDelegateCall(abi.encodeWithSelector(StakingVesting.setBlockRewardRange.selector, 1 ether, 5 ether));
  }

  function testConcrete_SetBlockRewardRange_RevertWhen_InvalidRange() external {
    vm.prank(_admin);
    vm.expectRevert(abi.encodeWithSelector(ErrInvalidArguments.selector, StakingVesting.setBlockRewardRange.selector));
    _proxy.functionDelegateCall(abi.encodeWithSelector(StakingVesting.setBlockRewardRange.selector, 5 ether, 1 ether)); // min > max
  }

  function testConcrete_UpdateBlockRewards_Success() external {
    IStakingVesting.Reward[] memory newRewards = new IStakingVesting.Reward[](2);
    newRewards[0] = IStakingVesting.Reward(2000, 3 ether);
    newRewards[1] = IStakingVesting.Reward(1500, 5 ether);

    vm.expectEmit(true, false, false, true);
    emit BlockProducerBonusPerBlockUpdated(_admin, newRewards);

    vm.prank(_admin);
    _proxy.functionDelegateCall(abi.encodeWithSelector(StakingVesting.updateBlockRewards.selector, newRewards));

    IStakingVesting.Reward[] memory updatedRewards = _stakingVesting.getBlockRewards();
    assertEq(updatedRewards.length, 2, "Should have 2 rewards");
    assertEq(updatedRewards[0].startBlock, 2000, "First reward start block should match");
    assertEq(updatedRewards[0].amount, 3 ether, "First reward amount should match");
    assertEq(updatedRewards[1].startBlock, 1500, "Second reward start block should match");
    assertEq(updatedRewards[1].amount, 5 ether, "Second reward amount should match");
  }

  function testConcrete_UpdateBlockRewards_RevertWhen_NotAdmin() external {
    IStakingVesting.Reward[] memory newRewards = new IStakingVesting.Reward[](1);
    newRewards[0] = IStakingVesting.Reward(2000, 3 ether);

    vm.prank(_user);
    vm.expectRevert();
    _proxy.functionDelegateCall(abi.encodeWithSelector(StakingVesting.updateBlockRewards.selector, newRewards));
  }

  function testConcrete_UpdateBlockRewards_RevertWhen_EmptyArray() external {
    IStakingVesting.Reward[] memory emptyRewards = new IStakingVesting.Reward[](0);

    vm.prank(_admin);
    vm.expectRevert(ErrEmptyArray.selector);
    _proxy.functionDelegateCall(abi.encodeWithSelector(StakingVesting.updateBlockRewards.selector, emptyRewards));
  }

  function testConcrete_UpdateBlockRewards_RevertWhen_OutOfBounds() external {
    IStakingVesting.Reward[] memory newRewards = new IStakingVesting.Reward[](1);
    newRewards[0] = IStakingVesting.Reward(2000, 15 ether); // Exceeds max of 10 ether

    vm.prank(_admin);
    vm.expectRevert(abi.encodeWithSelector(IStakingVesting.ErrOutOfBound.selector, 15 ether, 0 ether, 10 ether));
    _proxy.functionDelegateCall(abi.encodeWithSelector(StakingVesting.updateBlockRewards.selector, newRewards));
  }

  function testConcrete_UpdateBlockRewards_RevertWhen_OutOfOrder() external {
    IStakingVesting.Reward[] memory newRewards = new IStakingVesting.Reward[](2);
    newRewards[0] = IStakingVesting.Reward(1500, 3 ether);
    newRewards[1] = IStakingVesting.Reward(2000, 5 ether); // Should be descending order

    vm.prank(_admin);
    vm.expectRevert(abi.encodeWithSelector(IStakingVesting.ErrOutOfOrder.selector, 1, 2000, 1500));
    _proxy.functionDelegateCall(abi.encodeWithSelector(StakingVesting.updateBlockRewards.selector, newRewards));
  }

  function testConcrete_SetFastFinalityRewardPercentage_Success() external {
    uint256 newPercent = 9000; // 90%

    vm.expectEmit(false, false, false, true);
    emit FastFinalityRewardPercentageUpdated(newPercent);

    vm.prank(_admin);
    _proxy.functionDelegateCall(
      abi.encodeWithSelector(StakingVesting.setFastFinalityRewardPercentage.selector, newPercent)
    );

    assertEq(
      _stakingVesting.fastFinalityRewardPercentage(), newPercent, "Fast finality reward percentage should be updated"
    );
  }

  function testConcrete_SetFastFinalityRewardPercentage_RevertWhen_NotAdmin() external {
    vm.prank(_user);
    vm.expectRevert();
    _proxy.functionDelegateCall(abi.encodeWithSelector(StakingVesting.setFastFinalityRewardPercentage.selector, 9000));
  }

  function testConcrete_SetFastFinalityRewardPercentage_RevertWhen_ExceedsMaxPercentage() external {
    vm.prank(_admin);
    vm.expectRevert(
      abi.encodeWithSelector(ErrInvalidArguments.selector, StakingVesting.setFastFinalityRewardPercentage.selector)
    );
    _proxy.functionDelegateCall(
      abi.encodeWithSelector(StakingVesting.setFastFinalityRewardPercentage.selector, 100_001)
    ); // Exceeds 100%
  }

  function testConcrete_ReceiveRON() external {
    uint256 initialBalance = address(_stakingVesting).balance;
    uint256 amount = 10 ether;

    vm.deal(_user, amount);
    vm.prank(_user);
    (bool success,) =
      address(_stakingVesting).call{ value: amount }(abi.encodeWithSelector(StakingVesting.receiveRON.selector));

    assertTrue(success, "receiveRON should succeed");
    assertEq(address(_stakingVesting).balance, initialBalance + amount, "Contract balance should increase");
  }

  function testConcrete_RequestBonus_Success() external {
    // Fund the contract
    vm.deal(address(_stakingVesting), 100 ether);

    // Set block number to a valid reward block
    vm.roll(_blockRewards[_blockRewards.length - 1].startBlock);
    uint256 expectedBonus = _stakingVesting.blockProducerBlockBonus(block.number);
    uint256 initialBalance = address(_validatorContract).balance;

    vm.expectEmit(true, true, false, true);
    emit BonusTransferred(block.number, _validatorContract, expectedBonus, 0);

    vm.prank(_validatorContract);
    (bool success, uint256 blockProducerBonus, uint256 bridgeOperatorBonus, uint256 fastFinalityRewardPercent) =
      _stakingVesting.requestBonus(true, false);

    assertTrue(success, "Request bonus should succeed");
    assertEq(blockProducerBonus, expectedBonus, "Block producer bonus should match expected");
    assertEq(bridgeOperatorBonus, 0, "Bridge operator bonus should be 0");
    assertEq(fastFinalityRewardPercent, 8500, "Fast finality reward percent should match");
    assertEq(address(_validatorContract).balance, initialBalance + expectedBonus, "Validator balance should increase");
    assertEq(_stakingVesting.lastBlockSendingBonus(), block.number, "Last block sending bonus should be updated");
  }

  function testConcrete_RequestBonus_RevertWhen_NotValidatorContract() external {
    vm.prank(_user);
    vm.expectRevert(
      abi.encodeWithSelector(
        ErrUnexpectedInternalCall.selector, StakingVesting.requestBonus.selector, ContractType.VALIDATOR, _user
      )
    );
    _stakingVesting.requestBonus(true, false);
  }

  function testConcrete_RequestBonus_RevertWhen_BonusAlreadySent() external {
    vm.deal(address(_stakingVesting), 100 ether);
    vm.roll(_blockRewards[_blockRewards.length - 1].startBlock);

    // First request should succeed
    vm.prank(_validatorContract);
    _stakingVesting.requestBonus(true, false);

    // Second request in same block should fail
    vm.prank(_validatorContract);
    vm.expectRevert(IStakingVesting.ErrBonusAlreadySent.selector);
    _stakingVesting.requestBonus(true, false);
  }

  function testConcrete_RequestBonus_NoBonus() external {
    vm.roll(1000); // Block with no bonus

    vm.prank(_validatorContract);
    (bool success, uint256 blockProducerBonus, uint256 bridgeOperatorBonus, uint256 fastFinalityRewardPercent) =
      _stakingVesting.requestBonus(false, false);

    assertFalse(success, "Request should return false when no bonus to transfer");
    assertEq(blockProducerBonus, 0, "Block producer bonus should be 0");
    assertEq(bridgeOperatorBonus, 0, "Bridge operator bonus should be 0");
    assertEq(fastFinalityRewardPercent, 8500, "Fast finality reward percent should still be returned");
  }

  function testConcrete_RequestBonus_TransferFailed() external {
    // Don't fund the contract - transfer should fail
    vm.roll(_blockRewards[_blockRewards.length - 1].startBlock);
    uint256 expectedBonus = _stakingVesting.blockProducerBlockBonus(block.number);

    vm.expectEmit(true, true, false, true);
    emit BonusTransferFailed(block.number, _validatorContract, expectedBonus, 0, 0);

    vm.prank(_validatorContract);
    (bool success, uint256 blockProducerBonus, uint256 bridgeOperatorBonus, uint256 fastFinalityRewardPercent) =
      _stakingVesting.requestBonus(true, false);

    assertFalse(success, "Request should fail due to insufficient balance");
    assertEq(blockProducerBonus, 0, "Block producer bonus should be 0 on failure");
    assertEq(bridgeOperatorBonus, 0, "Bridge operator bonus should be 0 on failure");
    assertEq(fastFinalityRewardPercent, 0, "Fast finality reward percent should be 0 on failure");
  }

  function testConcrete_GetBlockRewards() external view {
    IStakingVesting.Reward[] memory rewards = _stakingVesting.getBlockRewards();
    assertEq(rewards.length, _blockRewards.length, "Should return correct number of rewards");

    for (uint256 i = 0; i < rewards.length; i++) {
      assertEq(rewards[i].startBlock, _blockRewards[i].startBlock, "Start block should match");
      assertEq(rewards[i].amount, _blockRewards[i].amount, "Amount should match");
    }
  }

  function testConcrete_GetBlockRewardRange() external view {
    (uint64 min, uint64 max) = _stakingVesting.getBlockRewardRange();
    assertEq(min, 0 ether, "Min reward should be 0 ether");
    assertEq(max, 10 ether, "Max reward should be 10 ether");
  }

  function testConcrete_LastBlockSendingBonus() external {
    assertEq(_stakingVesting.lastBlockSendingBonus(), 0, "Initial last block sending bonus should be 0");

    // Send a bonus request
    vm.deal(address(_stakingVesting), 100 ether);
    vm.roll(_blockRewards[_blockRewards.length - 1].startBlock);

    vm.prank(_validatorContract);
    _stakingVesting.requestBonus(true, false);

    assertEq(_stakingVesting.lastBlockSendingBonus(), block.number, "Last block sending bonus should be updated");
  }

  function testConcrete_FastFinalityRewardPercentage() external view {
    assertEq(_stakingVesting.fastFinalityRewardPercentage(), 8500, "Fast finality reward percentage should be 85%");
  }

  /**
   * @dev Test that validates the exact REP-0024 reward schedule implementation
   * This test ensures the contract properly implements the automatic staking reward distribution
   * as specified in REP-0024 with the correct start block and reward amounts
   */
  function testConcrete_REP0024_RewardSchedule() external {
    // REP-0024 specifies the first block that distributes staking rewards is 23155200
    uint256 REP0024_START_BLOCK = 23_155_200;
    uint256 blocksPerYear = 365 * 28_800; // 10,512,000 blocks per year

    // Create the exact REP-0024 reward schedule
    IStakingVesting.Reward[] memory rep0024Rewards = new IStakingVesting.Reward[](7);

    // After Year 8: 0 RON per block (starting from block 107251200)
    rep0024Rewards[0] = IStakingVesting.Reward(uint64(REP0024_START_BLOCK + 8 * blocksPerYear), uint64(0 ether));

    // Year 8: 6,000,000/365/28800 RON per block (starting from block 96739200)
    rep0024Rewards[1] = IStakingVesting.Reward(
      uint64(REP0024_START_BLOCK + 7 * blocksPerYear), uint64(uint256(6_000_000 ether) / 365 / 28_800)
    );

    // Year 7: 14,000,000/365/28800 RON per block (starting from block 86227200)
    rep0024Rewards[2] = IStakingVesting.Reward(
      uint64(REP0024_START_BLOCK + 6 * blocksPerYear), uint64(uint256(14_000_000 ether) / 365 / 28_800)
    );

    // Year 6: 18,000,000/365/28800 RON per block (starting from block 75715200)
    rep0024Rewards[3] = IStakingVesting.Reward(
      uint64(REP0024_START_BLOCK + 5 * blocksPerYear), uint64(uint256(18_000_000 ether) / 365 / 28_800)
    );

    // Year 5: 24,000,000/365/28800 RON per block (starting from block 65203200)
    rep0024Rewards[4] = IStakingVesting.Reward(
      uint64(REP0024_START_BLOCK + 4 * blocksPerYear), uint64(uint256(24_000_000 ether) / 365 / 28_800)
    );

    // Year 4: 28,000,000/365/28800 RON per block (starting from block 54691200)
    rep0024Rewards[5] = IStakingVesting.Reward(
      uint64(REP0024_START_BLOCK + 3 * blocksPerYear), uint64(uint256(28_000_000 ether) / 365 / 28_800)
    );

    // Years 1-3: 30,000,000/365/28800 RON per block (starting from block 23155200)
    rep0024Rewards[6] =
      IStakingVesting.Reward(uint64(REP0024_START_BLOCK), uint64(uint256(30_000_000 ether) / 365 / 28_800));

    // Deploy a fresh contract with REP-0024 compliant reward schedule
    vm.prank(_admin);
    _proxy.functionDelegateCall(abi.encodeWithSelector(StakingVesting.updateBlockRewards.selector, rep0024Rewards));

    // Test each reward period according to REP-0024

    // Test Years 1-3: 30,000,000/365/28800 RON per block
    uint256 expectedRewardYears1to3 = uint256(30_000_000 ether) / 365 / 28_800;
    assertEq(
      _stakingVesting.blockProducerBlockBonus(REP0024_START_BLOCK),
      expectedRewardYears1to3,
      "Years 1-3 reward should match REP-0024"
    );
    assertEq(
      _stakingVesting.blockProducerBlockBonus(REP0024_START_BLOCK + 3 * blocksPerYear - 1),
      expectedRewardYears1to3,
      "Years 1-3 end reward should match REP-0024"
    );

    // Test Year 4: 28,000,000/365/28800 RON per block
    uint256 expectedRewardYear4 = uint256(28_000_000 ether) / 365 / 28_800;
    assertEq(
      _stakingVesting.blockProducerBlockBonus(REP0024_START_BLOCK + 3 * blocksPerYear),
      expectedRewardYear4,
      "Year 4 reward should match REP-0024"
    );
    assertEq(
      _stakingVesting.blockProducerBlockBonus(REP0024_START_BLOCK + 4 * blocksPerYear - 1),
      expectedRewardYear4,
      "Year 4 end reward should match REP-0024"
    );

    // Test Year 5: 24,000,000/365/28800 RON per block
    uint256 expectedRewardYear5 = uint256(24_000_000 ether) / 365 / 28_800;
    assertEq(
      _stakingVesting.blockProducerBlockBonus(REP0024_START_BLOCK + 4 * blocksPerYear),
      expectedRewardYear5,
      "Year 5 reward should match REP-0024"
    );
    assertEq(
      _stakingVesting.blockProducerBlockBonus(REP0024_START_BLOCK + 5 * blocksPerYear - 1),
      expectedRewardYear5,
      "Year 5 end reward should match REP-0024"
    );

    // Test Year 6: 18,000,000/365/28800 RON per block
    uint256 expectedRewardYear6 = uint256(18_000_000 ether) / 365 / 28_800;
    assertEq(
      _stakingVesting.blockProducerBlockBonus(REP0024_START_BLOCK + 5 * blocksPerYear),
      expectedRewardYear6,
      "Year 6 reward should match REP-0024"
    );
    assertEq(
      _stakingVesting.blockProducerBlockBonus(REP0024_START_BLOCK + 6 * blocksPerYear - 1),
      expectedRewardYear6,
      "Year 6 end reward should match REP-0024"
    );

    // Test Year 7: 14,000,000/365/28800 RON per block
    uint256 expectedRewardYear7 = uint256(14_000_000 ether) / 365 / 28_800;
    assertEq(
      _stakingVesting.blockProducerBlockBonus(REP0024_START_BLOCK + 6 * blocksPerYear),
      expectedRewardYear7,
      "Year 7 reward should match REP-0024"
    );
    assertEq(
      _stakingVesting.blockProducerBlockBonus(REP0024_START_BLOCK + 7 * blocksPerYear - 1),
      expectedRewardYear7,
      "Year 7 end reward should match REP-0024"
    );

    // Test Year 8: 6,000,000/365/28800 RON per block
    uint256 expectedRewardYear8 = uint256(6_000_000 ether) / 365 / 28_800;
    assertEq(
      _stakingVesting.blockProducerBlockBonus(REP0024_START_BLOCK + 7 * blocksPerYear),
      expectedRewardYear8,
      "Year 8 reward should match REP-0024"
    );
    assertEq(
      _stakingVesting.blockProducerBlockBonus(REP0024_START_BLOCK + 8 * blocksPerYear - 1),
      expectedRewardYear8,
      "Year 8 end reward should match REP-0024"
    );

    // Test After Year 8: 0 RON per block
    assertEq(
      _stakingVesting.blockProducerBlockBonus(REP0024_START_BLOCK + 8 * blocksPerYear),
      0,
      "After Year 8 reward should be 0 per REP-0024"
    );
    assertEq(
      _stakingVesting.blockProducerBlockBonus(REP0024_START_BLOCK + 10 * blocksPerYear),
      0,
      "Future blocks should have 0 reward per REP-0024"
    );

    // Verify the exact reward amounts match the calculated values from REP-0024
    assertEq(
      expectedRewardYears1to3, 2_853_881_278_538_812_785, "Years 1-3 reward amount should be ~2.854 RON per block"
    );
    assertEq(expectedRewardYear4, 2_663_622_526_636_225_266, "Year 4 reward amount should be ~2.664 RON per block");
    assertEq(expectedRewardYear5, 2_283_105_022_831_050_228, "Year 5 reward amount should be ~2.283 RON per block");
    assertEq(expectedRewardYear6, 1_712_328_767_123_287_671, "Year 6 reward amount should be ~1.712 RON per block");
    assertEq(expectedRewardYear7, 1_331_811_263_318_112_633, "Year 7 reward amount should be ~1.332 RON per block");
    assertEq(expectedRewardYear8, 570_776_255_707_762_557, "Year 8 reward amount should be ~0.571 RON per block");
  }

  // ============================================
  // FUZZ TESTS
  // ============================================

  /**
   * @dev Fuzz test for blockProducerBlockBonus function
   * Tests that the function always returns a value within the configured reward range
   * and behaves predictably for any block number
   */
  function testFuzz_BlockProducerBlockBonus_AlwaysReturnsValidReward(
    uint256 blockNumber
  ) external view {
    // Bound the block number to reasonable range to avoid overflow
    blockNumber = bound(blockNumber, 0, type(uint64).max);

    uint64 bonus = _stakingVesting.blockProducerBlockBonus(blockNumber);
    (uint64 min, uint64 max) = _stakingVesting.getBlockRewardRange();

    // Bonus should always be within the configured range
    assertGe(bonus, min, "Bonus should be >= minimum reward amount");
    assertLe(bonus, max, "Bonus should be <= maximum reward amount");
  }

  /**
   * @dev Fuzz test for reward consistency within same reward period
   * Tests that rewards are consistent within the same reward period
   */
  function testFuzz_BlockProducerBlockBonus_ConsistencyWithinPeriod(
    uint256 blockNumber1,
    uint256 blockNumber2
  ) external view {
    // Get a valid reward period start block
    vm.assume(_blockRewards.length > 0);
    uint8 rewardIndex = uint8(bound(blockNumber1, 0, _blockRewards.length - 1));
    IStakingVesting.Reward memory reward = _blockRewards[rewardIndex];

    // Test blocks within the same reward period
    uint64 nextPeriodStart = rewardIndex > 0 ? _blockRewards[rewardIndex - 1].startBlock : type(uint64).max;
    blockNumber1 = bound(blockNumber1, reward.startBlock, nextPeriodStart - 1);
    blockNumber2 = bound(blockNumber2, reward.startBlock, nextPeriodStart - 1);

    uint64 bonus1 = _stakingVesting.blockProducerBlockBonus(blockNumber1);
    uint64 bonus2 = _stakingVesting.blockProducerBlockBonus(blockNumber2);

    // Rewards should be consistent within the same period
    assertEq(bonus1, bonus2, "Rewards should be consistent within the same reward period");
    assertEq(bonus1, reward.amount, "Reward should match the period amount");
  }

  /**
   * @dev Fuzz test for setBlockRewardRange function
   * Tests proper validation and state updates with random valid ranges
   */
  function testFuzz_SetBlockRewardRange_ValidRanges(uint64 minReward, uint64 maxReward) external {
    // Ensure valid range by making min <= max
    if (minReward > maxReward) {
      (minReward, maxReward) = (maxReward, minReward);
    }

    vm.prank(_admin);
    _proxy.functionDelegateCall(
      abi.encodeWithSelector(StakingVesting.setBlockRewardRange.selector, minReward, maxReward)
    );

    (uint64 actualMin, uint64 actualMax) = _stakingVesting.getBlockRewardRange();
    assertEq(actualMin, minReward, "Min reward should be set correctly");
    assertEq(actualMax, maxReward, "Max reward should be set correctly");
  }

  /**
   * @dev Fuzz test for setBlockRewardRange with invalid ranges
   * Tests that function properly reverts when min > max
   */
  function testFuzz_SetBlockRewardRange_InvalidRanges_RevertWhen_MinGreaterThanMax(
    uint64 minReward,
    uint64 maxReward
  ) external {
    // Only test when min > max
    vm.assume(minReward > maxReward);
    vm.assume(minReward != maxReward); // Avoid edge case where they're equal

    vm.prank(_admin);
    vm.expectRevert(abi.encodeWithSelector(ErrInvalidArguments.selector, StakingVesting.setBlockRewardRange.selector));
    _proxy.functionDelegateCall(
      abi.encodeWithSelector(StakingVesting.setBlockRewardRange.selector, minReward, maxReward)
    );
  }

  /**
   * @dev Fuzz test for updateBlockRewards with single reward
   * Tests reward updates with random valid single reward entries
   */
  function testFuzz_UpdateBlockRewards_SingleReward(uint64 startBlock, uint64 amount) external {
    // Ensure amount is within valid range
    (uint64 min, uint64 max) = _stakingVesting.getBlockRewardRange();
    amount = uint64(bound(amount, min, max));

    IStakingVesting.Reward[] memory rewards = new IStakingVesting.Reward[](1);
    rewards[0] = IStakingVesting.Reward(startBlock, amount);

    vm.prank(_admin);
    _proxy.functionDelegateCall(abi.encodeWithSelector(StakingVesting.updateBlockRewards.selector, rewards));

    // Verify the reward was set correctly
    IStakingVesting.Reward[] memory storedRewards = _stakingVesting.getBlockRewards();
    assertEq(storedRewards.length, 1, "Should have 1 reward");
    assertEq(storedRewards[0].startBlock, startBlock, "Start block should match");
    assertEq(storedRewards[0].amount, amount, "Amount should match");

    // Test that block reward calculation works correctly
    if (startBlock > 0) {
      assertEq(_stakingVesting.blockProducerBlockBonus(startBlock), amount, "Reward at start block should match");
      assertEq(_stakingVesting.blockProducerBlockBonus(startBlock - 1), min, "Reward before start should be minimum");
    }
  }

  /**
   * @dev Fuzz test for reward amount bounds validation
   * Tests that updateBlockRewards properly validates reward amounts are within bounds
   */
  function testFuzz_UpdateBlockRewards_RevertWhen_AmountOutOfBounds(
    uint64 amount
  ) external {
    (uint64 min, uint64 max) = _stakingVesting.getBlockRewardRange();

    // Only test amounts that are actually out of bounds
    vm.assume(amount < min || amount > max);

    IStakingVesting.Reward[] memory rewards = new IStakingVesting.Reward[](1);
    rewards[0] = IStakingVesting.Reward(1000, amount);

    vm.prank(_admin);
    vm.expectRevert(abi.encodeWithSelector(IStakingVesting.ErrOutOfBound.selector, amount, min, max));
    _proxy.functionDelegateCall(abi.encodeWithSelector(StakingVesting.updateBlockRewards.selector, rewards));
  }

  /**
   * @dev Fuzz test for reward ordering validation
   * Tests that updateBlockRewards enforces descending order of start blocks
   */
  function testFuzz_UpdateBlockRewards_RevertWhen_InvalidOrder(uint64 startBlock1, uint64 startBlock2) external {
    // Ensure we have invalid order (ascending instead of descending)
    vm.assume(startBlock1 < startBlock2);

    (uint64 min, uint64 max) = _stakingVesting.getBlockRewardRange();
    uint64 validAmount = min + (max - min) / 2; // Use mid-range amount

    IStakingVesting.Reward[] memory rewards = new IStakingVesting.Reward[](2);
    rewards[0] = IStakingVesting.Reward(startBlock1, validAmount); // First should be higher
    rewards[1] = IStakingVesting.Reward(startBlock2, validAmount); // Second should be lower

    vm.prank(_admin);
    vm.expectRevert(abi.encodeWithSelector(IStakingVesting.ErrOutOfOrder.selector, 1, startBlock2, startBlock1));
    _proxy.functionDelegateCall(abi.encodeWithSelector(StakingVesting.updateBlockRewards.selector, rewards));
  }

  /**
   * @dev Fuzz test for fast finality reward percentage
   * Tests that percentage is properly validated and set
   */
  function testFuzz_SetFastFinalityRewardPercentage_ValidPercentages(
    uint256 percent
  ) external {
    // Bound to valid percentage range (0-10000, where 10000 = 100%)
    percent = bound(percent, 0, 10_000);

    vm.prank(_admin);
    _proxy.functionDelegateCall(
      abi.encodeWithSelector(StakingVesting.setFastFinalityRewardPercentage.selector, percent)
    );

    assertEq(
      _stakingVesting.fastFinalityRewardPercentage(), percent, "Fast finality percentage should be set correctly"
    );
  }

  /**
   * @dev Fuzz test for fast finality reward percentage validation
   * Tests that percentages > 100% are properly rejected
   */
  function testFuzz_SetFastFinalityRewardPercentage_RevertWhen_ExceedsMaxPercentage(
    uint256 percent
  ) external {
    // Only test percentages that exceed 100%
    vm.assume(percent > 10_000);

    vm.prank(_admin);
    vm.expectRevert(
      abi.encodeWithSelector(ErrInvalidArguments.selector, StakingVesting.setFastFinalityRewardPercentage.selector)
    );
    _proxy.functionDelegateCall(
      abi.encodeWithSelector(StakingVesting.setFastFinalityRewardPercentage.selector, percent)
    );
  }

  /**
   * @dev Fuzz test for requestBonus function with random block timing
   * Tests that requestBonus behaves correctly across different block scenarios
   */
  function testFuzz_RequestBonus_BlockProgression(
    uint256 blockNumber
  ) external {
    // Bound to reasonable block range
    blockNumber = bound(blockNumber, 1, type(uint64).max / 2);

    // Fund the contract
    vm.deal(address(_stakingVesting), 100 ether);

    // Move to the test block
    vm.roll(blockNumber);

    // Calculate expected bonus for this block
    uint64 expectedBonus = _stakingVesting.blockProducerBlockBonus(blockNumber);

    vm.prank(_validatorContract);
    (bool success, uint256 actualBonus,, uint256 fastFinalityPercent) = _stakingVesting.requestBonus(true, false);

    if (expectedBonus > 0) {
      assertTrue(success, "Request should succeed when bonus > 0");
      assertEq(actualBonus, expectedBonus, "Actual bonus should match expected");
      assertEq(fastFinalityPercent, 8500, "Fast finality percent should be returned");
      assertEq(_stakingVesting.lastBlockSendingBonus(), blockNumber, "Last block sending bonus should be updated");
    } else {
      // When expected bonus is 0, the function returns false
      assertFalse(success, "Request should return false when no bonus");
      assertEq(actualBonus, 0, "Actual bonus should be 0");
    }
  }

  /**
   * @dev Fuzz test for reward transition boundaries
   * Tests that rewards transition correctly at exact boundary blocks
   */
  function testFuzz_RewardTransitionBoundaries(
    uint8 rewardIndex
  ) external view {
    // Bound to valid reward index range
    rewardIndex = uint8(bound(rewardIndex, 0, _blockRewards.length - 1));

    if (rewardIndex < _blockRewards.length) {
      IStakingVesting.Reward memory currentReward = _blockRewards[rewardIndex];

      // Test at the exact transition block
      uint64 rewardAtTransition = _stakingVesting.blockProducerBlockBonus(currentReward.startBlock);
      assertEq(rewardAtTransition, currentReward.amount, "Reward at transition block should match");

      // Test one block before (if valid)
      if (currentReward.startBlock > 0) {
        uint64 rewardBefore = _stakingVesting.blockProducerBlockBonus(currentReward.startBlock - 1);

        if (rewardIndex < _blockRewards.length - 1) {
          // Should get the next reward's amount (or minimum if no next reward)
          IStakingVesting.Reward memory nextReward = _blockRewards[rewardIndex + 1];
          assertEq(rewardBefore, nextReward.amount, "Reward before transition should match next reward");
        }
      }
    }
  }

  /**
   * @dev Invariant test: Total supply constraints
   * Tests that the reward system maintains reasonable total supply bounds
   */
  function testFuzz_RewardSystemInvariants(uint256 startBlock, uint256 endBlock) external view {
    // Bound to reasonable range
    startBlock = bound(startBlock, 0, type(uint64).max / 4);
    endBlock = bound(endBlock, startBlock, startBlock + 1_000_000); // Test up to 1M block range

    uint256 totalRewards = 0;
    uint256 maxSingleBlockReward = 0;

    // Calculate total rewards over the range (limit iterations for gas)
    for (uint256 i = startBlock; i <= endBlock && i < startBlock + 1000; i++) {
      uint64 reward = _stakingVesting.blockProducerBlockBonus(i);
      totalRewards += reward;
      if (reward > maxSingleBlockReward) {
        maxSingleBlockReward = reward;
      }
    }

    (uint64 min, uint64 max) = _stakingVesting.getBlockRewardRange();

    // Invariants that should always hold
    assertLe(maxSingleBlockReward, max, "No single block reward should exceed maximum");
    assertGe(maxSingleBlockReward, min, "Maximum observed reward should be >= minimum (if any rewards exist)");

    // Ensure total rewards don't exceed unreasonable bounds (prevents overflow scenarios)
    assertLe(
      totalRewards, uint256(max) * (endBlock - startBlock + 1), "Total rewards should not exceed theoretical maximum"
    );
  }
}
