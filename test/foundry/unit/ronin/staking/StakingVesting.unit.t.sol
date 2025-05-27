// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";

import { TransparentUpgradeableProxyV2 } from "src/extensions/TransparentUpgradeableProxyV2.sol";
import { IStakingVesting, StakingVesting } from "src/ronin/StakingVesting.sol";

contract StakingVestingTest is Test {
  StakingVesting internal _stakingVesting;
  address internal _proxyAdmin = makeAddr("proxyAdmin");
  address internal _validatorContract = makeAddr("validatorContract");
  IStakingVesting.Reward[] internal _blockRewards;

  function setUp() public {
    address logic = address(new StakingVesting());
    TransparentUpgradeableProxyV2 proxy = new TransparentUpgradeableProxyV2(
      logic, _proxyAdmin, abi.encodeWithSelector(StakingVesting.initialize.selector, _validatorContract, 0, 0)
    );
    _stakingVesting = StakingVesting(address(proxy));
    vm.label(address(_stakingVesting), "StakingVesting");
    _stakingVesting.initializeV3(8500); // Set fast finality reward percentage to 85%

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

    _stakingVesting.initializeV5(uint64(0 ether), uint64(10 ether), blockRewards); // Set min and max reward amounts

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
}
