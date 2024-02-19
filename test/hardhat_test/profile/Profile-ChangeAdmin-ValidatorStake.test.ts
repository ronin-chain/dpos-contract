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
  StakingVesting,
  TransparentUpgradeableProxyV2__factory,
  MockProfile__factory,
  Profile__factory,
  Profile,
} from '../../../src/types';
import * as RoninValidatorSet from '../helpers/ronin-validator-set';
import { RoleAccess, generateSamplePubkey, getLastBlockTimestamp, mineBatchTxs } from '../helpers/utils';
import { defaultTestConfig, deployTestSuite } from '../helpers/fixture';
import { GovernanceAdminInterface } from '../../../src/script/governance-admin-interface';
import { Address } from 'hardhat-deploy/dist/types';
import {
  createManyTrustedOrganizationAddressSets,
  TrustedOrganizationAddressSet,
} from '../helpers/address-set-types/trusted-org-set-type';
import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';
import { VoteType } from '../../../src/script/proposal';
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
import { CandidateProfileStruct } from '../../../src/types/IProfile';
import { DEFAULT_ADDRESS } from '../../../src/utils';

let validatorContract: MockRoninValidatorSetExtended;
let stakingVesting: StakingVesting;
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
let signers: SignerWithAddress[];
let trustedOrgs: TrustedOrganizationAddressSet[];
let validatorCandidates: ValidatorCandidateAddressSet[];
let whitelistedCandidates: WhitelistedCandidateAddressSet[];

let oldAdmins: SignerWithAddress[] = [];

let currentValidatorSet: string[];
let lastPeriod: BigNumber;
let epoch: BigNumber;

let snapshotId: any;

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
const topUpAmount = BigNumber.from(100_000_000_000);
const slashDoubleSignAmount = BigNumber.from(2000);
const maxCommissionRate = 30_00; // 30%
const defaultMinCommissionRate = 0;

describe.skip('Profile: change admin', () => {
  before(async () => {
    [coinbase, poolAdmin, consensusAddr, bridgeOperator, delegator, deployer, ...signers] = await ethers.getSigners();
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
    } = await deployTestSuite('Profile-ChangeAdmin')({
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
    stakingVesting = StakingVesting__factory.connect(stakingVestingContractAddress, deployer);
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
  });

  after(async () => {
    await network.provider.send('hardhat_setCoinbase', [ethers.constants.AddressZero]);
  });

  describe('Change admin from A0 to A1', async () => {
    before(async () => {
      // Submit block reward before change the admin address for testing reward
      await network.provider.send('hardhat_setCoinbase', [validatorCandidates[0].consensusAddr.address]);
      await validatorContract.connect(validatorCandidates[0].consensusAddr).submitBlockReward({value: 10_000});

      snapshotId = await network.provider.send('evm_snapshot');
    })

    describe('Effects on profile contract', async () => {
      it('Should the Profile returns correct information before change the admin', async () => {
        let profile : CandidateProfileStruct;
        profile = await profileContract.getId2Profile(validatorCandidates[0].consensusAddr.address);
        expect(profile.admin).eq(validatorCandidates[0].poolAdmin.address);
        expect(profile.treasury).eq(validatorCandidates[0].poolAdmin.address);
        expect(profile.consensus).eq(validatorCandidates[0].consensusAddr.address);
      });

      it('Should the admin can change his admin address', async () => {
        oldAdmins.push(validatorCandidates[0].poolAdmin);
        let newAdmin = signers[signers.length - 1];
        let tx = await profileContract.connect(validatorCandidates[0].poolAdmin).requestChangeAdminAddress(validatorCandidates[0].consensusAddr.address, newAdmin.address);
        await expect(tx).emit(profileContract, "ProfileAddressChanged").withArgs(validatorCandidates[0].consensusAddr.address, RoleAccess.CANDIDATE_ADMIN, newAdmin.address);
        validatorCandidates[0].poolAdmin = newAdmin;
        validatorCandidates[0].candidateAdmin = newAdmin;
        validatorCandidates[0].treasuryAddr = newAdmin;
      });

      it('Should the Profile returns the new admin address and treasury address', async () => {
        let profile : CandidateProfileStruct;
        profile = await profileContract.getId2Profile(validatorCandidates[0].consensusAddr.address);
        expect(profile.admin).eq(validatorCandidates[0].poolAdmin.address);
        expect(profile.treasury).eq(validatorCandidates[0].treasuryAddr.address);
        expect(profile.consensus).eq(validatorCandidates[0].consensusAddr.address);
      });
    })

    describe('Effects on Validator contract', async () => {
      it('Should the Validator contract return the new admin on validator candidate info', async () => {
        let candidateInfo = await validatorContract.getCandidateInfo(validatorCandidates[0].consensusAddr.address);
        expect(candidateInfo.__shadowedAdmin).eq(validatorCandidates[0].poolAdmin.address)
        expect(candidateInfo.__shadowedTreasury).eq(validatorCandidates[0].poolAdmin.address)
      })
    })

    describe('Effects on Staking contract', async () => {
      it('Should the Staking contract returns new admin on Pool info', async () => {
        let poolDetail = await stakingContract.getPoolDetail(validatorCandidates[0].consensusAddr.address);
        expect(poolDetail.admin).eq(validatorCandidates[0].poolAdmin.address);

        let poolDetailById = await stakingContract.getPoolDetailById(validatorCandidates[0].consensusAddr.address);
        expect(poolDetailById.admin).eq(validatorCandidates[0].poolAdmin.address);

        expect(await stakingContract.isAdminOfActivePool(oldAdmins[0].address)).eq(false)
        expect(await stakingContract.isAdminOfActivePool(validatorCandidates[0].candidateAdmin.address)).eq(true)

        expect(await stakingContract.getPoolAddressOf(oldAdmins[0].address)).eq(DEFAULT_ADDRESS)
        expect(await stakingContract.getPoolAddressOf(validatorCandidates[0].candidateAdmin.address)).eq(validatorCandidates[0].consensusAddr.address);
      })

      it('Should the pool info clear the staking amount of A0, and update the staking amount of A1', async () => {
        expect(await stakingContract.getStakingAmount(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].candidateAdmin.address)).gt(0);
        expect(await stakingContract.getStakingAmount(validatorCandidates[0].consensusAddr.address, oldAdmins[0].address)).eq(0);
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
        })

        it('Should the old admin A0 cannot claim the reward', async () => {
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, oldAdmins[0].address)).eq(0);
        let rewards =  await stakingContract.connect(oldAdmins[0]).getRewards(oldAdmins[0].address, [validatorCandidates[0].consensusAddr.address]);
        expect(rewards[0]).eq(0);

        let tx = await stakingContract.connect(oldAdmins[0]).claimRewards([validatorCandidates[0].consensusAddr.address]);
        await expect(tx).emit(stakingContract, 'RewardClaimed').withArgs(validatorCandidates[0].consensusAddr.address, oldAdmins[0].address, 0);
      })

      it('Should the staking reward is accumulated from the before changing address until now, and only A1 can redeem', async () => {
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].candidateAdmin.address)).eq(15999);

        let rewards =  await stakingContract.connect(validatorCandidates[0].poolAdmin).getRewards(validatorCandidates[0].poolAdmin.address, [validatorCandidates[0].consensusAddr.address]);
        expect(rewards[0]).eq(15999);

        let tx = await stakingContract.connect(validatorCandidates[0].poolAdmin).claimRewards([validatorCandidates[0].consensusAddr.address]);
        await expect(tx).emit(stakingContract, 'RewardClaimed').withArgs(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].poolAdmin.address, 15999);
      })

      it('Should the old admin A0 cannot staking to self', async() => {
        await expect(stakingContract.connect(oldAdmins[0]).stake(validatorCandidates[0].consensusAddr.address, {value: 1000 })).revertedWithCustomError(stakingContract, 'ErrOnlyPoolAdminAllowed');
      })

      it('Should the old admin A0 cannot delegate to self', async() => {
        await expect(stakingContract.connect(oldAdmins[0]).delegate(validatorCandidates[0].consensusAddr.address, {value: 1000})).revertedWithCustomError(stakingContract, 'ErrPoolAdminForbidden');
      })

      let stakingBalance: BigNumber;
      it('Should the new admin A1 can stake more to self', async() => {
        let poolDetail = await stakingContract.getPoolDetail(validatorCandidates[0].consensusAddr.address);
        stakingBalance = poolDetail.stakingAmount;

        let tx = await stakingContract.connect(validatorCandidates[0].poolAdmin).stake(validatorCandidates[0].consensusAddr.address, {value: 1000 });
        await expect(tx!).emit(stakingContract, 'Staked').withArgs(validatorCandidates[0].consensusAddr.address, 1000);
      })

      it('Should the pool info update the staking amount of A1', async () => {
        let poolDetail = await stakingContract.getPoolDetail(validatorCandidates[0].consensusAddr.address);
        expect(poolDetail.stakingAmount.sub(stakingBalance)).eq(1000);
      })

      it.skip('Should the staking reward of A1 is calculated correctly', async() => {})
    })
  });

  describe('Change admin from A1 to A2', async () => {
    let newAdmin2: SignerWithAddress;
    it('Should the old admin A0 cannot change the address', async () => {
      newAdmin2 = signers[signers.length - 2];
      await expect(profileContract.connect(oldAdmins[0]).requestChangeAdminAddress(validatorCandidates[0].consensusAddr.address, newAdmin2.address)).revertedWithCustomError(profileContract, 'ErrUnauthorized');
    });

    it('Should the admin A1 cannot change the admin address back to A0', async () => {
      await expect(profileContract.connect(validatorCandidates[0].poolAdmin).requestChangeAdminAddress(validatorCandidates[0].consensusAddr.address, oldAdmins[0].address)).revertedWithCustomError(profileContract, 'ErrDuplicatedInfo');
    });

    it('Should the admin A1 can change the admin to A2 and returns correct info', async () => {
      oldAdmins.push(validatorCandidates[0].poolAdmin);
      let tx = await profileContract.connect(validatorCandidates[0].poolAdmin).requestChangeAdminAddress(validatorCandidates[0].consensusAddr.address, newAdmin2.address);
      await expect(tx).emit(profileContract, "ProfileAddressChanged").withArgs(validatorCandidates[0].consensusAddr.address, RoleAccess.CANDIDATE_ADMIN, newAdmin2.address);
      validatorCandidates[0].poolAdmin = newAdmin2;
      validatorCandidates[0].candidateAdmin = newAdmin2;
      validatorCandidates[0].treasuryAddr = newAdmin2;
    });
  });

  // describe('Change admin from A0 to A1, and verifying delegator reward', async () => {
  //   before(async () => {
  //     await network.provider.send('evm_revert', [snapshotId]);

  //     await stakingContract.connect(delegator).delegate(validatorCandidates[0].consensusAddr.address, {value: minValidatorStakingAmount});

  //     let tx: ContractTransaction;
  //     await EpochController.setTimestampToPeriodEnding();
  //     epoch = await validatorContract.epochOf(await ethers.provider.getBlockNumber());
  //     lastPeriod = await validatorContract.currentPeriod();
  //     await mineBatchTxs(async () => {
  //       await validatorContract.endEpoch();
  //       tx = await validatorContract.connect(validatorCandidates[0].consensusAddr).wrapUpEpoch();
  //     });

  //     await expect(tx!).emit(validatorContract, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
  //     lastPeriod = await validatorContract.currentPeriod();

  //     // Submit block reward before change the admin address for testing reward
  //     await network.provider.send('hardhat_setCoinbase', [validatorCandidates[0].consensusAddr.address]);
  //     await validatorContract.connect(validatorCandidates[0].consensusAddr).submitBlockReward({value: 10_000});
  //   });

  //   it('Should the staking reward of delegator is distributed before validator changes admin', async () => {
  //     let tx: ContractTransaction;
  //     await EpochController.setTimestampToPeriodEnding();
  //     epoch = await validatorContract.epochOf(await ethers.provider.getBlockNumber());
  //     lastPeriod = await validatorContract.currentPeriod();
  //     await mineBatchTxs(async () => {
  //       await validatorContract.endEpoch();
  //       tx = await validatorContract.connect(validatorCandidates[0].consensusAddr).wrapUpEpoch();
  //     });

  //     await expect(tx!).emit(validatorContract, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
  //     lastPeriod = await validatorContract.currentPeriod();

  //     await expect(tx!)
  //       .emit(validatorContract, 'MiningRewardDistributed')
  //       .withArgs(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].treasuryAddr.address, 2000);

  //     expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, delegator.address)).eq(0);
  //     let rewards =  await stakingContract.connect(oldAdmins[0]).getRewards(delegator.address, [validatorCandidates[0].consensusAddr.address]);
  //     expect(rewards[0]).eq(0);

  //     tx = await stakingContract.connect(delegator).claimRewards([validatorCandidates[0].consensusAddr.address]);
  //     await expect(tx).emit(stakingContract, 'RewardClaimed').withArgs(validatorCandidates[0].consensusAddr.address, delegator.address, 0);
  //   });

  //   it('Should the mining reward transfer to the new treasury address A1', async () => {
  //     // Submit block reward after changing the admin address for testing reward
  //     await network.provider.send('hardhat_setCoinbase', [validatorCandidates[0].consensusAddr.address]);
  //     await validatorContract.connect(validatorCandidates[0].consensusAddr).submitBlockReward({value: 10_000});

  //     let tx: ContractTransaction;
  //     for (let i = 0; i < 1; i++) {
  //       await EpochController.setTimestampToPeriodEnding();
  //       epoch = await validatorContract.epochOf(await ethers.provider.getBlockNumber());
  //       lastPeriod = await validatorContract.currentPeriod();
  //       await mineBatchTxs(async () => {
  //         await validatorContract.endEpoch();
  //         tx = await validatorContract.connect(validatorCandidates[0].consensusAddr).wrapUpEpoch();
  //       });

  //       await expect(tx!).emit(validatorContract, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);
  //       lastPeriod = await validatorContract.currentPeriod();
  //     }

  //     await expect(tx!)
  //       .emit(validatorContract, 'MiningRewardDistributed')
  //       .withArgs(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].treasuryAddr.address, 4000)
  //     })
  // });
});
