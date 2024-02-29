import { expect } from 'chai';
import { BigNumber, ContractTransaction } from 'ethers';
import { ethers, network } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  Staking,
  MockRoninValidatorSetExtended,
  MockRoninValidatorSetExtended__factory,
  Staking__factory,
  MockSlashIndicatorExtended__factory,
  MockSlashIndicatorExtended,
  RoninGovernanceAdmin__factory,
  RoninGovernanceAdmin,
  StakingVesting__factory,
  MockProfile__factory,
  Profile__factory,
  Profile,
} from '../../../src/types';
import { RoleAccess, generateSamplePubkey, getLastBlockTimestamp, mineBatchTxs } from '../helpers/utils';
import { deployTestSuite } from '../helpers/fixture';
import { GovernanceAdminInterface } from '../../../src/script/governance-admin-interface';
import {
  createManyTrustedOrganizationAddressSets,
  TrustedOrganizationAddressSet,
} from '../helpers/address-set-types/trusted-org-set-type';
import {
  ValidatorCandidateAddressSet,
  createManyValidatorCandidateAddressSets,
} from '../helpers/address-set-types/validator-candidate-set-type';
import {
  WhitelistedCandidateAddressSet,
  mergeToManyWhitelistedCandidateAddressSets,
} from '../helpers/address-set-types/whitelisted-candidate-set-type';
import { initializeTestSuite } from '../helpers/initializer';
import { EpochController } from '../helpers/ronin-validator-set';

let validatorContract: MockRoninValidatorSetExtended;
let stakingContract: Staking;
let slashIndicator: MockSlashIndicatorExtended;
let profileContract: Profile;
let governanceAdmin: RoninGovernanceAdmin;
let governanceAdminInterface: GovernanceAdminInterface;

let coinbase: SignerWithAddress;
let poolAdmin: SignerWithAddress;
let candidateAdmin: SignerWithAddress;
let consensusAddr: SignerWithAddress;
let treasury: SignerWithAddress;
let bridgeOperator: SignerWithAddress;
let deployer: SignerWithAddress;
let delegator: SignerWithAddress;
let delegator2: SignerWithAddress;
let signers: SignerWithAddress[];
let trustedOrgs: TrustedOrganizationAddressSet[];
let validatorCandidates: ValidatorCandidateAddressSet[];
let whitelistedCandidates: WhitelistedCandidateAddressSet[];

let oldAdmins: SignerWithAddress[] = [];

let lastPeriod: BigNumber;
let epoch: BigNumber;


const localValidatorCandidatesLength = 6;
const localTrustedOrgsLength = 1;

const slashAmountForUnavailabilityTier2Threshold = 100;
const maxValidatorNumber = 4;
const maxPrioritizedValidatorNumber = 1;
const maxValidatorCandidate = 100;
const minValidatorStakingAmount = BigNumber.from(20000);
const blockProducerBonusPerBlock = BigNumber.from(5000);
const bridgeOperatorBonusPerBlock = BigNumber.from(37);
const zeroTopUpAmount = 0;
const slashDoubleSignAmount = BigNumber.from(2000);
const maxCommissionRate = 30_00; // 30%

describe('Profile: change admin - delegator reward (staking reward on the changing day is splitted to delegators)', () => {
  before(async () => {
    [coinbase, poolAdmin, consensusAddr, bridgeOperator, delegator, delegator2, deployer, ...signers] = await ethers.getSigners();
    candidateAdmin = poolAdmin;
    treasury = poolAdmin;

    trustedOrgs = createManyTrustedOrganizationAddressSets(signers.splice(0, localTrustedOrgsLength * 3));
    validatorCandidates = createManyValidatorCandidateAddressSets(
      signers.splice(0, localValidatorCandidatesLength * 3)
    );
    whitelistedCandidates = mergeToManyWhitelistedCandidateAddressSets([trustedOrgs[0]], [validatorCandidates[0]]);

    await network.provider.send('hardhat_setCoinbase', [consensusAddr.address]);

    const {
      slashContractAddress,
      validatorContractAddress,
      stakingContractAddress,
      roninGovernanceAdminAddress,
      stakingVestingContractAddress,
      profileAddress,
      fastFinalityTrackingAddress,
      roninTrustedOrganizationAddress,
    } = await deployTestSuite('Profile-ChangeAdmin-DelegatorStake')({
      slashIndicatorArguments: {
        doubleSignSlashing: {
          slashDoubleSignAmount,
        },
        unavailabilitySlashing: {
          slashAmountForUnavailabilityTier2Threshold,
        },
      },
      stakingArguments: {
        minValidatorStakingAmount,
        maxCommissionRate,
      },
      stakingVestingArguments: {
        blockProducerBonusPerBlock,
        bridgeOperatorBonusPerBlock,
        topupAmount: zeroTopUpAmount,
      },
      roninValidatorSetArguments: {
        maxValidatorNumber,
        maxPrioritizedValidatorNumber,
        maxValidatorCandidate,
      },
      roninTrustedOrganizationArguments: {
        trustedOrganizations: trustedOrgs.map((v) => ({
          consensusAddr: v.consensusAddr.address,
          governor: v.governor.address,
          __deprecatedBridgeVoter: v.__deprecatedBridgeVoter.address,
          weight: 100,
          addedBlock: 0,
        })),
      },
    });

    await initializeTestSuite({
      deployer,
      fastFinalityTrackingAddress,
      profileAddress,
      slashContractAddress,
      stakingContractAddress,
      validatorContractAddress,
      roninTrustedOrganizationAddress,
      maintenanceContractAddress: undefined,
    });

    validatorContract = MockRoninValidatorSetExtended__factory.connect(validatorContractAddress, deployer);
    slashIndicator = MockSlashIndicatorExtended__factory.connect(slashContractAddress, deployer);
    stakingContract = Staking__factory.connect(stakingContractAddress, deployer);
    profileContract = Profile__factory.connect(profileAddress, deployer);
    governanceAdmin = RoninGovernanceAdmin__factory.connect(roninGovernanceAdminAddress, deployer);
    governanceAdminInterface = new GovernanceAdminInterface(
      governanceAdmin,
      network.config.chainId!,
      undefined,
      ...trustedOrgs.map((_) => _.governor)
    );

    const mockProfileLogic = await new MockProfile__factory(deployer).deploy();
    await mockProfileLogic.deployed();
    await governanceAdminInterface.upgrade(profileAddress, mockProfileLogic.address);

    const mockValidatorLogic = await new MockRoninValidatorSetExtended__factory(deployer).deploy();
    await mockValidatorLogic.deployed();
    await governanceAdminInterface.upgrade(validatorContract.address, mockValidatorLogic.address);
    await validatorContract.initEpoch();

    const mockSlashIndicator = await new MockSlashIndicatorExtended__factory(deployer).deploy();
    await mockSlashIndicator.deployed();
    await governanceAdminInterface.upgrade(slashIndicator.address, mockSlashIndicator.address);

    validatorCandidates = validatorCandidates.slice(0, maxValidatorNumber);
    for (let i = 0; i < maxValidatorNumber; i++) {
      await stakingContract
        .connect(validatorCandidates[i].poolAdmin)
        .applyValidatorCandidate(
          validatorCandidates[i].candidateAdmin.address,
          validatorCandidates[i].consensusAddr.address,
          validatorCandidates[i].treasuryAddr.address,
          20_00,
          generateSamplePubkey(),
          '0x',
          { value: minValidatorStakingAmount.mul(2).add(maxValidatorNumber).sub(i) }
        );
    }

    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);

    await EpochController.setTimestampToPeriodEnding();
    epoch = await validatorContract.epochOf(await ethers.provider.getBlockNumber());
    await mineBatchTxs(async () => {
      await validatorContract.endEpoch();
      await validatorContract.connect(coinbase).wrapUpEpoch();
    });
    expect(await validatorContract.getValidators()).deep.equal(validatorCandidates.map((_) => _.consensusAddr.address));
    await network.provider.send('hardhat_setCoinbase', [validatorCandidates[0].consensusAddr.address]);


    // Delegate
    await stakingContract.connect(delegator).delegate(validatorCandidates[0].consensusAddr.address, {value: minValidatorStakingAmount});

    let tx: ContractTransaction;
    await EpochController.setTimestampToPeriodEnding();
    epoch = await validatorContract.epochOf(await ethers.provider.getBlockNumber());
    lastPeriod = await validatorContract.currentPeriod();
    await mineBatchTxs(async () => {
      await validatorContract.endEpoch();
      tx = await validatorContract.connect(validatorCandidates[0].consensusAddr).wrapUpEpoch();
    });

    await expect(tx!).emit(validatorContract, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
    lastPeriod = await validatorContract.currentPeriod();
  });

  after(async () => {
    await network.provider.send('hardhat_setCoinbase', [ethers.constants.AddressZero]);
  });


  describe('Change admin from A0 to A1, 1 delegator, and verifying delegator reward', async () => {
    describe('Before change admin, submit 20_000 reward; wrap up', async () => {
      before(async () => {
        // Submit block reward before change the admin address for testing reward
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[0].consensusAddr.address]);
        await validatorContract.connect(validatorCandidates[0].consensusAddr).submitBlockReward({value: 20_000});
      })

      it('Should mining reward of validator is 4_000', async () => {
        let tx: ContractTransaction;
        await EpochController.setTimestampToPeriodEnding();
        epoch = await validatorContract.epochOf(await ethers.provider.getBlockNumber());
        lastPeriod = await validatorContract.currentPeriod();
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          tx = await validatorContract.connect(validatorCandidates[0].consensusAddr).wrapUpEpoch();
        });

        await expect(tx!).emit(validatorContract, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
        lastPeriod = await validatorContract.currentPeriod();

        await expect(tx!)
          .emit(validatorContract, 'MiningRewardDistributed')
          .withArgs(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].treasuryAddr.address, 4000);
      });

      it("Should validator's staking reward is 10667", async () => {
        // Validator claim
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].candidateAdmin.address)).eq(10667);
        let rewards =  await stakingContract.connect(delegator).getRewards(validatorCandidates[0].candidateAdmin.address, [validatorCandidates[0].consensusAddr.address]);
        expect(rewards[0]).eq(10667);

        let tx = await stakingContract.connect(validatorCandidates[0].candidateAdmin).claimRewards([validatorCandidates[0].consensusAddr.address]);
        await expect(tx).emit(stakingContract, 'RewardClaimed').withArgs(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].candidateAdmin.address, 10667);
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].candidateAdmin.address)).eq(0);
      })

      it("Should delegator's staking reward is 5332", async () => {
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, delegator.address)).eq(5332);
        let rewards =  await stakingContract.connect(delegator).getRewards(delegator.address, [validatorCandidates[0].consensusAddr.address]);
        expect(rewards[0]).eq(5332);

        let tx = await stakingContract.connect(delegator).claimRewards([validatorCandidates[0].consensusAddr.address]);
        await expect(tx).emit(stakingContract, 'RewardClaimed').withArgs(validatorCandidates[0].consensusAddr.address, delegator.address, 5332);
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, delegator.address)).eq(0);
      })
    })

    describe('Before change admin, submit 10_000 reward, after change admin, submit 10_000 reward more; wrap up', async () => {
      it('Should the admin can change his admin address', async () => {
        // Submit block reward before changing the admin address for testing reward
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[0].consensusAddr.address]);
        await validatorContract.connect(validatorCandidates[0].consensusAddr).submitBlockReward({value: 10_000});

        oldAdmins.push(validatorCandidates[0].poolAdmin);
        let newAdmin = signers[signers.length - 1];
        let tx = await profileContract.connect(validatorCandidates[0].poolAdmin).changeAdminAddr(validatorCandidates[0].consensusAddr.address, newAdmin.address);
        await expect(tx).emit(profileContract, "ProfileAddressChanged").withArgs(validatorCandidates[0].consensusAddr.address, RoleAccess.CANDIDATE_ADMIN, newAdmin.address);
        validatorCandidates[0].poolAdmin = newAdmin;
        validatorCandidates[0].candidateAdmin = newAdmin;
        validatorCandidates[0].treasuryAddr = newAdmin;
      });

      it('Should the mining reward transfer to the new treasury address A1', async () => {
        // Submit block reward after changing the admin address for testing reward
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[0].consensusAddr.address]);
        await validatorContract.connect(validatorCandidates[0].consensusAddr).submitBlockReward({value: 10_000});

        let tx: ContractTransaction;
        for (let i = 0; i < 1; i++) {
          await EpochController.setTimestampToPeriodEnding();
          epoch = await validatorContract.epochOf(await ethers.provider.getBlockNumber());
          lastPeriod = await validatorContract.currentPeriod();
          await mineBatchTxs(async () => {
            await validatorContract.endEpoch();
            tx = await validatorContract.connect(validatorCandidates[0].consensusAddr).wrapUpEpoch();
          });

          await expect(tx!).emit(validatorContract, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
          lastPeriod = await validatorContract.currentPeriod();
        }

        await expect(tx!)
          .emit(validatorContract, 'MiningRewardDistributed')
          .withArgs(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].treasuryAddr.address, 4000)
      });

      it("Should validator's staking reward of today is 0, the actual amount (10_667) is splitted for delegators", async () => {
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].candidateAdmin.address)).eq(0);
        let rewards =  await stakingContract.connect(delegator).getRewards(validatorCandidates[0].candidateAdmin.address, [validatorCandidates[0].consensusAddr.address]);
        expect(rewards[0]).eq(0);

        let tx = await stakingContract.connect(validatorCandidates[0].candidateAdmin).claimRewards([validatorCandidates[0].consensusAddr.address]);
        await expect(tx).emit(stakingContract, 'RewardClaimed').withArgs(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].candidateAdmin.address, 0);
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].candidateAdmin.address)).eq(0);
      })

      it('Should the delegator reward is still correct (16_000) after the validator change the admin address' /* 5332 + 10667 */, async () => {
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, delegator.address)).eq(16000);
        let rewards =  await stakingContract.connect(delegator).getRewards(delegator.address, [validatorCandidates[0].consensusAddr.address]);
        expect(rewards[0]).eq(16000);

        let tx = await stakingContract.connect(delegator).claimRewards([validatorCandidates[0].consensusAddr.address]);
        await expect(tx).emit(stakingContract, 'RewardClaimed').withArgs(validatorCandidates[0].consensusAddr.address, delegator.address, 16000);
      })
    });
  });

  describe('Change admin from A1 to A2, 1 delegator, multi-period and verifying delegator reward', async () => {
    describe('Before change admin, submit 20_000 reward; wrap up; submit 12_000 reward more; wrap up;', async () => {
      it('Should mining reward of validator in the first day is 4_000', async () => {
        // Submit block reward before change the admin address for testing reward
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[0].consensusAddr.address]);
        await validatorContract.connect(validatorCandidates[0].consensusAddr).submitBlockReward({value: 20_000});

        let tx: ContractTransaction;
        await EpochController.setTimestampToPeriodEnding();
        epoch = await validatorContract.epochOf(await ethers.provider.getBlockNumber());
        lastPeriod = await validatorContract.currentPeriod();
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          tx = await validatorContract.connect(validatorCandidates[0].consensusAddr).wrapUpEpoch();
        });

        await expect(tx!).emit(validatorContract, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
        lastPeriod = await validatorContract.currentPeriod();

        await expect(tx!)
          .emit(validatorContract, 'MiningRewardDistributed')
          .withArgs(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].treasuryAddr.address, 4_000)
      })

      it('Should mining reward of validator in the second day is 2_400', async () => {
        // Submit block reward before change the admin address for testing reward
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[0].consensusAddr.address]);
        await validatorContract.connect(validatorCandidates[0].consensusAddr).submitBlockReward({value: 12_000});

        let tx: ContractTransaction;
        await EpochController.setTimestampToPeriodEnding();
        epoch = await validatorContract.epochOf(await ethers.provider.getBlockNumber());
        lastPeriod = await validatorContract.currentPeriod();
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          tx = await validatorContract.connect(validatorCandidates[0].consensusAddr).wrapUpEpoch();
        });

        await expect(tx!).emit(validatorContract, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
        lastPeriod = await validatorContract.currentPeriod();

        await expect(tx!)
          .emit(validatorContract, 'MiningRewardDistributed')
          .withArgs(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].treasuryAddr.address, 2_400);
      });

      it("Should validator's staking reward is 17067", async () => {
        // Validator claim
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].candidateAdmin.address)).eq(17067);
        let rewards =  await stakingContract.connect(delegator).getRewards(validatorCandidates[0].candidateAdmin.address, [validatorCandidates[0].consensusAddr.address]);
        expect(rewards[0]).eq(17067);

        let tx = await stakingContract.connect(validatorCandidates[0].candidateAdmin).claimRewards([validatorCandidates[0].consensusAddr.address]);
        await expect(tx).emit(stakingContract, 'RewardClaimed').withArgs(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].candidateAdmin.address, 17067);
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].candidateAdmin.address)).eq(0);
      })

      it("Should delegator's staking reward is 8532", async () => {
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, delegator.address)).eq(8532);
        let rewards =  await stakingContract.connect(delegator).getRewards(delegator.address, [validatorCandidates[0].consensusAddr.address]);
        expect(rewards[0]).eq(8532);

        let tx = await stakingContract.connect(delegator).claimRewards([validatorCandidates[0].consensusAddr.address]);
        await expect(tx).emit(stakingContract, 'RewardClaimed').withArgs(validatorCandidates[0].consensusAddr.address, delegator.address, 8532);
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, delegator.address)).eq(0);
      })
    })

    describe('Before change admin, submit 20_000 reward; wrap up; after change admin, submit 12_000 reward more; wrap up', async () => {
      it('Should mining reward of validator in the first day is 4_000', async () => {
        // Submit block reward before change the admin address for testing reward
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[0].consensusAddr.address]);
        await validatorContract.connect(validatorCandidates[0].consensusAddr).submitBlockReward({value: 20_000});

        let tx: ContractTransaction;
        await EpochController.setTimestampToPeriodEnding();
        epoch = await validatorContract.epochOf(await ethers.provider.getBlockNumber());
        lastPeriod = await validatorContract.currentPeriod();
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          tx = await validatorContract.connect(validatorCandidates[0].consensusAddr).wrapUpEpoch();
        });

        await expect(tx!).emit(validatorContract, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
        lastPeriod = await validatorContract.currentPeriod();

        await expect(tx!)
          .emit(validatorContract, 'MiningRewardDistributed')
          .withArgs(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].treasuryAddr.address, 4_000)
      })

      it('Should the admin can change his admin address', async () => {
        oldAdmins.push(validatorCandidates[0].poolAdmin);
        let newAdmin = signers[signers.length - 2];
        let tx = await profileContract.connect(validatorCandidates[0].poolAdmin).changeAdminAddr(validatorCandidates[0].consensusAddr.address, newAdmin.address);
        await expect(tx).emit(profileContract, "ProfileAddressChanged").withArgs(validatorCandidates[0].consensusAddr.address, RoleAccess.CANDIDATE_ADMIN, newAdmin.address);
        validatorCandidates[0].poolAdmin = newAdmin;
        validatorCandidates[0].candidateAdmin = newAdmin;
        validatorCandidates[0].treasuryAddr = newAdmin;
      });

      it('Should the mining reward of the second day (2_400) transfer to the new treasury address A2', async () => {
        // Submit block reward after changing the admin address for testing reward
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[0].consensusAddr.address]);
        await validatorContract.connect(validatorCandidates[0].consensusAddr).submitBlockReward({value: 12_000});

        let tx: ContractTransaction;
        await EpochController.setTimestampToPeriodEnding();
        epoch = await validatorContract.epochOf(await ethers.provider.getBlockNumber());
        lastPeriod = await validatorContract.currentPeriod();
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          tx = await validatorContract.connect(validatorCandidates[0].consensusAddr).wrapUpEpoch();
        });

        await expect(tx!).emit(validatorContract, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
        lastPeriod = await validatorContract.currentPeriod();


        await expect(tx!)
          .emit(validatorContract, 'MiningRewardDistributed')
          .withArgs(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].treasuryAddr.address, 2_400)
      });

      it("Should validator's staking reward of the previous days (10667) must be claimed by the old admin", async() => {
        // reward of old admin
        let oldAdmin = oldAdmins[oldAdmins.length - 1];
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, oldAdmin.address)).eq(10667);
        let rewards =  await stakingContract.connect(delegator).getRewards(oldAdmin.address, [validatorCandidates[0].consensusAddr.address]);
        expect(rewards[0]).eq(10667);

        let tx = await stakingContract.connect(oldAdmin).claimRewards([validatorCandidates[0].consensusAddr.address]);
        await expect(tx).emit(stakingContract, 'RewardClaimed').withArgs(validatorCandidates[0].consensusAddr.address, oldAdmin.address, 10667);
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, oldAdmin.address)).eq(0);
      })

      it("Should validator's staking reward of today is 0 after the validator change the admin address and splitted to delegators", /* 7000 is cleared out */ async () => {
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].candidateAdmin.address)).eq(0);
        let rewards =  await stakingContract.connect(delegator).getRewards(validatorCandidates[0].candidateAdmin.address, [validatorCandidates[0].consensusAddr.address]);
        expect(rewards[0]).eq(0);

        let tx = await stakingContract.connect(validatorCandidates[0].candidateAdmin).claimRewards([validatorCandidates[0].consensusAddr.address]);
        await expect(tx).emit(stakingContract, 'RewardClaimed').withArgs(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].candidateAdmin.address, 0);
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].candidateAdmin.address)).eq(0);
      })

      it('Should the delegator reward is still correct (8532) + dispensed by the portion of validator staking (7000) after the validator change the admin address', async () => {
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, delegator.address)).eq(14932);
        let rewards =  await stakingContract.connect(delegator).getRewards(delegator.address, [validatorCandidates[0].consensusAddr.address]);
        expect(rewards[0]).eq(14932);

        let tx = await stakingContract.connect(delegator).claimRewards([validatorCandidates[0].consensusAddr.address]);
        await expect(tx).emit(stakingContract, 'RewardClaimed').withArgs(validatorCandidates[0].consensusAddr.address, delegator.address, 14932);
      })
    });
  });

  describe('Change admin from A2 to A3, 2 delegators, and verifying delegator reward', async () => {
    before(async () => {
      await stakingContract.connect(delegator2).delegate(validatorCandidates[0].consensusAddr.address, {value: minValidatorStakingAmount.div(3)});

      let tx: ContractTransaction;
      await EpochController.setTimestampToPeriodEnding();
      epoch = await validatorContract.epochOf(await ethers.provider.getBlockNumber());
      lastPeriod = await validatorContract.currentPeriod();
      await mineBatchTxs(async () => {
        await validatorContract.endEpoch();
        tx = await validatorContract.connect(validatorCandidates[0].consensusAddr).wrapUpEpoch();
      });

      await expect(tx!).emit(validatorContract, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
      lastPeriod = await validatorContract.currentPeriod();

      // Submit block reward before change the admin address for testing reward
      await network.provider.send('hardhat_setCoinbase', [validatorCandidates[0].consensusAddr.address]);
      await validatorContract.connect(validatorCandidates[0].consensusAddr).submitBlockReward({value: 10_000});
    });

    describe('[Not change admin] Before change admin, submit 20_000 reward; wrap up ', async () => {
      before(async () => {
        // Submit block reward before change the admin address for testing reward
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[0].consensusAddr.address]);
        await validatorContract.connect(validatorCandidates[0].consensusAddr).submitBlockReward({value: 10_000});
      })

      it('Should mining reward of validator is 4_000', async () => {
        let tx: ContractTransaction;
        await EpochController.setTimestampToPeriodEnding();
        epoch = await validatorContract.epochOf(await ethers.provider.getBlockNumber());
        lastPeriod = await validatorContract.currentPeriod();
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          tx = await validatorContract.connect(validatorCandidates[0].consensusAddr).wrapUpEpoch();
        });

        await expect(tx!).emit(validatorContract, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
        lastPeriod = await validatorContract.currentPeriod();

        await expect(tx!)
          .emit(validatorContract, 'MiningRewardDistributed')
          .withArgs(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].treasuryAddr.address, 4000);
      });

      it("Should validator's staking reward is 9600", async () => {
        // Validator claim
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].candidateAdmin.address)).eq(9600);
        let rewards =  await stakingContract.connect(delegator).getRewards(validatorCandidates[0].candidateAdmin.address, [validatorCandidates[0].consensusAddr.address]);
        expect(rewards[0]).eq(9600);

        let tx = await stakingContract.connect(validatorCandidates[0].candidateAdmin).claimRewards([validatorCandidates[0].consensusAddr.address]);
        await expect(tx).emit(stakingContract, 'RewardClaimed').withArgs(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].candidateAdmin.address, 9600);
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].candidateAdmin.address)).eq(0);
      })

      it("Should sum of delegator's staking reward is 6398", async () => {
        // Delegator 1
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, delegator.address)).eq(4799);
        let rewards =  await stakingContract.connect(delegator).getRewards(delegator.address, [validatorCandidates[0].consensusAddr.address]);
        expect(rewards[0]).eq(4799);

        let tx = await stakingContract.connect(delegator).claimRewards([validatorCandidates[0].consensusAddr.address]);
        await expect(tx).emit(stakingContract, 'RewardClaimed').withArgs(validatorCandidates[0].consensusAddr.address, delegator.address, 4799);
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, delegator.address)).eq(0);

        // Delegator 2
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, delegator2.address)).eq(1599);
        rewards =  await stakingContract.connect(delegator2).getRewards(delegator2.address, [validatorCandidates[0].consensusAddr.address]);
        expect(rewards[0]).eq(1599);

        tx = await stakingContract.connect(delegator2).claimRewards([validatorCandidates[0].consensusAddr.address]);
        await expect(tx).emit(stakingContract, 'RewardClaimed').withArgs(validatorCandidates[0].consensusAddr.address, delegator2.address, 1599);
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, delegator2.address)).eq(0);
      })
    })

    describe('[Change admin] Before change admin, submit 10_000 reward; after change admin, submit 10_000 reward more; wrap up', async () => {
      it('Should the admin can change his admin address', async () => {
        // Submit block reward before changing the admin address for testing reward
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[0].consensusAddr.address]);
        await validatorContract.connect(validatorCandidates[0].consensusAddr).submitBlockReward({value: 10_000});

        oldAdmins.push(validatorCandidates[0].poolAdmin);
        let newAdmin = signers[signers.length - 3];
        let tx = await profileContract.connect(validatorCandidates[0].poolAdmin).changeAdminAddr(validatorCandidates[0].consensusAddr.address, newAdmin.address);
        await expect(tx).emit(profileContract, "ProfileAddressChanged").withArgs(validatorCandidates[0].consensusAddr.address, RoleAccess.CANDIDATE_ADMIN, newAdmin.address);
        validatorCandidates[0].poolAdmin = newAdmin;
        validatorCandidates[0].candidateAdmin = newAdmin;
        validatorCandidates[0].treasuryAddr = newAdmin;
      });

      it('Should the mining reward transfer to the new treasury address A1', async () => {
        // Submit block reward after changing the admin address for testing reward
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[0].consensusAddr.address]);
        await validatorContract.connect(validatorCandidates[0].consensusAddr).submitBlockReward({value: 10_000});

        let tx: ContractTransaction;
        for (let i = 0; i < 1; i++) {
          await EpochController.setTimestampToPeriodEnding();
          epoch = await validatorContract.epochOf(await ethers.provider.getBlockNumber());
          lastPeriod = await validatorContract.currentPeriod();
          await mineBatchTxs(async () => {
            await validatorContract.endEpoch();
            tx = await validatorContract.connect(validatorCandidates[0].consensusAddr).wrapUpEpoch();
          });

          await expect(tx!).emit(validatorContract, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
          lastPeriod = await validatorContract.currentPeriod();
        }

        await expect(tx!)
          .emit(validatorContract, 'MiningRewardDistributed')
          .withArgs(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].treasuryAddr.address, 4000)
      });

      it("Should validator's staking reward is still correct 0 after the validator change the admin address, and splitted to delegators", /* 9600 */ async () => {
        // Validator claim
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].candidateAdmin.address)).eq(0);
        let rewards =  await stakingContract.connect(delegator).getRewards(validatorCandidates[0].candidateAdmin.address, [validatorCandidates[0].consensusAddr.address]);
        expect(rewards[0]).eq(0);

        let tx = await stakingContract.connect(validatorCandidates[0].candidateAdmin).claimRewards([validatorCandidates[0].consensusAddr.address]);
        await expect(tx).emit(stakingContract, 'RewardClaimed').withArgs(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].candidateAdmin.address, 0);
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].candidateAdmin.address)).eq(0);
      })

      it('Should the delegator #1 reward is still correct (11_999) after the validator change the admin address' /* 4799 + 7200 */, async () => {
        // Delegator 1
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, delegator.address)).eq(12000);
        let rewards =  await stakingContract.connect(delegator).getRewards(delegator.address, [validatorCandidates[0].consensusAddr.address]);
        expect(rewards[0]).eq(12000);

        let tx = await stakingContract.connect(delegator).claimRewards([validatorCandidates[0].consensusAddr.address]);
        await expect(tx).emit(stakingContract, 'RewardClaimed').withArgs(validatorCandidates[0].consensusAddr.address, delegator.address, 12000);
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, delegator.address)).eq(0);
      })

      it('Should the delegator #2 reward is still correct (3_999) after the validator change the admin address' /* 1599 + 2400 */ , async () => {
        // Delegator 2
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, delegator2.address)).eq(3999);
        let rewards =  await stakingContract.connect(delegator2).getRewards(delegator2.address, [validatorCandidates[0].consensusAddr.address]);
        expect(rewards[0]).eq(3999);

        let tx = await stakingContract.connect(delegator2).claimRewards([validatorCandidates[0].consensusAddr.address]);
        await expect(tx).emit(stakingContract, 'RewardClaimed').withArgs(validatorCandidates[0].consensusAddr.address, delegator2.address, 3999);
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, delegator2.address)).eq(0);
      })
    });
  });
});
