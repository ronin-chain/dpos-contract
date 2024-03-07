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

let oldCssLst: SignerWithAddress[] = [];

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

describe('Profile: change consensus', () => {
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
    } = await deployTestSuite('Profile-ChangeConsensus')({
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
  });

  after(async () => {
    await network.provider.send('hardhat_setCoinbase', [ethers.constants.AddressZero]);
  });

  describe('Change consensus from C0 to C1', async () => {
    before(async () => {
      // Submit block reward before change the admin address for testing reward
      await network.provider.send('hardhat_setCoinbase', [validatorCandidates[0].consensusAddr.address]);
      await validatorContract.connect(validatorCandidates[0].consensusAddr).submitBlockReward({value: 10_000});

      snapshotId = await network.provider.send('evm_snapshot');
    })

    describe('Effects on profile contract', async () => {
      it('Should the Profile returns correct information before change the consensus', async () => {
        let profile : CandidateProfileStruct;
        profile = await profileContract.getId2Profile(validatorCandidates[0].consensusAddr.address);
        expect(profile.admin).eq(validatorCandidates[0].poolAdmin.address);
        expect(profile.treasury).eq(validatorCandidates[0].poolAdmin.address);
        expect(profile.consensus).eq(validatorCandidates[0].consensusAddr.address);
      });

      it('Should the Validator contract return the validator candidate info correctly before changing', async () => {
        let candidateInfo = await validatorContract.getCandidateInfo(validatorCandidates[0].consensusAddr.address);
        expect(candidateInfo.__shadowedAdmin).eq(validatorCandidates[0].poolAdmin.address)
        expect(candidateInfo.__shadowedTreasury).eq(validatorCandidates[0].poolAdmin.address)
        expect(candidateInfo.__shadowedConsensus).eq(validatorCandidates[0].consensusAddr.address)
      })

      it('Should the admin can change his consensus address', async () => {
        oldCssLst.push(validatorCandidates[0].consensusAddr);
        let newConsensus = signers[signers.length - 1];
        let tx = await profileContract.connect(validatorCandidates[0].poolAdmin).changeConsensusAddr(validatorCandidates[0].consensusAddr.address, newConsensus.address);
        await expect(tx).emit(profileContract, "ProfileAddressChanged").withArgs(validatorCandidates[0].consensusAddr.address, RoleAccess.CONSENSUS, newConsensus.address);
        validatorCandidates[0].consensusAddr = newConsensus;
      });

      it('Should the Profile returns the new consensus address', async () => {
        let profile : CandidateProfileStruct;
        profile = await profileContract.getId2Profile(validatorCandidates[0].cid.address);
        expect(profile.id).eq(validatorCandidates[0].cid.address);
        expect(profile.consensus).eq(validatorCandidates[0].consensusAddr.address);
        expect(profile.admin).eq(validatorCandidates[0].poolAdmin.address);
        expect(profile.treasury).eq(validatorCandidates[0].treasuryAddr.address);
      });
    })

    describe('Effects on Validator contract', async () => {
      it('Should the Validator contract return the new consensus on validator candidate info', async () => {
        let candidateInfo = await validatorContract.getCandidateInfo(validatorCandidates[0].consensusAddr.address);
        expect(candidateInfo.__shadowedAdmin).eq(validatorCandidates[0].poolAdmin.address)
        expect(candidateInfo.__shadowedTreasury).eq(validatorCandidates[0].poolAdmin.address)
        expect(candidateInfo.__shadowedConsensus).eq(validatorCandidates[0].consensusAddr.address)
      })

      // it('Should the old consensus cannot submit block reward', async () => {
      //   await network.provider.send('hardhat_setCoinbase', [oldCssLst[0].address]);
      //   let tx = await validatorContract.connect(oldCssLst[0]).submitBlockReward({value: 10_000});
      //   await expect(tx).emit(validatorContract, "BlockRewardDeprecated").withArgs(oldCssLst[0].address, 10_000, anyValue);
      // });

      it('Should the new consensus can submit block reward', async () => {
        await network.provider.send('hardhat_setCoinbase', [validatorCandidates[0].consensusAddr.address]);
        let tx = await validatorContract.connect(validatorCandidates[0].consensusAddr).submitBlockReward({value: 10_000});
        await expect(tx).emit(validatorContract, "BlockRewardSubmitted").withArgs(validatorCandidates[0].cid.address, 10_000, anyValue);
      });

      // it('Should the old consensus cannot wrapup epoch', async () => {
      //   await EpochController.setTimestampToPeriodEnding();
      //   epoch = await validatorContract.epochOf(await ethers.provider.getBlockNumber());
      //   await mineBatchTxs(async () => {
      //     await validatorContract.endEpoch();
      //     await network.provider.send('hardhat_setCoinbase', [oldCssLst[0].address]);
      //     await expect(validatorContract.connect(oldCssLst[0]).wrapUpEpoch()).revertedWithCustomError(validatorContract, "ErrCallerMustBeCoinbase");
      //   });
      // });

      it('Should the new consensus can wrapup epoch and receive mining reward of before and after changing consensus', async() => {
        let tx: ContractTransaction;
        await EpochController.setTimestampToPeriodEnding();
        epoch = await validatorContract.epochOf(await ethers.provider.getBlockNumber());
        lastPeriod = await validatorContract.currentPeriod();
        await mineBatchTxs(async () => {
          await validatorContract.endEpoch();
          await network.provider.send('hardhat_setCoinbase', [validatorCandidates[0].consensusAddr.address]);
          tx = await validatorContract.connect(validatorCandidates[0].consensusAddr).wrapUpEpoch();
        });

        await expect(tx!).emit(validatorContract, 'WrappedUpEpoch').withArgs(lastPeriod, epoch, true);

        await expect(tx!)
          .emit(validatorContract, 'MiningRewardDistributed')
          .withArgs(validatorCandidates[0].cid.address, validatorCandidates[0].treasuryAddr.address, 4000);
      });

      it('Should the reward info query by consensus return correctly: getReward(consensus) > 0', async () => {
        expect(await stakingContract.getReward(validatorCandidates[0].consensusAddr.address, validatorCandidates[0].candidateAdmin.address)).eq(15_999);
      });

      it('Should the reward info query by id return correctly: getReward(id) == 0', async () => {
        // expect(await stakingContract.getReward(validatorCandidates[0].cid.address, validatorCandidates[0].candidateAdmin.address)).eq(0);
        await expect(stakingContract.getReward(validatorCandidates[0].cid.address, validatorCandidates[0].candidateAdmin.address)).revertedWithCustomError(profileContract, "ErrLookUpIdFailed");
      })

      it('Should not be able to claim reward by ids', async () => {
        // let tx = await stakingContract.connect(validatorCandidates[0].candidateAdmin).claimRewards([validatorCandidates[0].cid.address]);
        // await expect(tx).emit(stakingContract, 'RewardClaimed').withArgs(DEFAULT_ADDRESS, validatorCandidates[0].candidateAdmin.address, 0);
        await expect(stakingContract.connect(validatorCandidates[0].candidateAdmin).claimRewards([validatorCandidates[0].cid.address])).revertedWithCustomError(profileContract, "ErrLookUpIdFailed").withArgs(validatorCandidates[0].cid.address);
      })

      it('Should not be able to claim reward by consensuses', async () => {
        let tx = await stakingContract.connect(validatorCandidates[0].candidateAdmin).claimRewards([validatorCandidates[0].consensusAddr.address]);
        await expect(tx).emit(stakingContract, 'RewardClaimed').withArgs(validatorCandidates[0].cid.address, validatorCandidates[0].candidateAdmin.address, 15999);
      })
    })

    describe('Effects on Staking contract', async () => {
      it('Should the Staking contract returns new consensus on Pool info', async () => {
        let poolDetail = await stakingContract.getPoolDetail(validatorCandidates[0].consensusAddr.address);
        expect(poolDetail.admin).eq(validatorCandidates[0].poolAdmin.address);

        await expect(stakingContract.getPoolDetail(validatorCandidates[0].cid.address)).revertedWithCustomError(profileContract, "ErrLookUpIdFailed").withArgs(validatorCandidates[0].cid.address);

        let poolDetailById = await stakingContract.getPoolDetailById(validatorCandidates[0].cid.address);
        expect(poolDetailById.admin).eq(validatorCandidates[0].poolAdmin.address);

        poolDetailById = await stakingContract.getPoolDetailById(validatorCandidates[0].consensusAddr.address);
        expect(poolDetailById.admin).eq(DEFAULT_ADDRESS);

        expect(await stakingContract.isAdminOfActivePool(validatorCandidates[0].candidateAdmin.address)).eq(true)
        expect(await stakingContract.getPoolAddressOf(validatorCandidates[0].candidateAdmin.address)).eq(validatorCandidates[0].cid.address);
      })
    })
  });

  describe.skip('Change admin from C1 to C2', async () => {
    let newConsensus2: SignerWithAddress;

    it('Should the admin cannot change the consensus address back to C0', async () => {
      newConsensus2 = signers[signers.length - 2];
      await expect(profileContract.connect(validatorCandidates[0].poolAdmin).changeConsensusAddr(validatorCandidates[0].consensusAddr.address, oldCssLst[0].address)).revertedWithCustomError(profileContract, 'ErrUnauthorized');
    });

    it('Should the admin can change the consensus to C2 and returns correct info', async () => {
      oldCssLst.push(validatorCandidates[0].poolAdmin);
      let tx = await profileContract.connect(validatorCandidates[0].poolAdmin).changeConsensusAddr(validatorCandidates[0].consensusAddr.address, newConsensus2.address);
      await expect(tx).emit(profileContract, "ProfileAddressChanged").withArgs(validatorCandidates[0].consensusAddr.address, RoleAccess.CONSENSUS, newConsensus2.address);
      validatorCandidates[0].consensusAddr = newConsensus2;

      let profile = await profileContract.getId2Profile(validatorCandidates[0].consensusAddr.address);
      expect(profile.admin).eq(validatorCandidates[0].poolAdmin.address);
      expect(profile.treasury).eq(validatorCandidates[0].poolAdmin.address);
      expect(profile.consensus).eq(validatorCandidates[0].consensusAddr.address);
      expect(profile.id).eq(validatorCandidates[0].cid.address);
    });
  });
});
