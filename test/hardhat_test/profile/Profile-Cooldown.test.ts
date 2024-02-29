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
const profileChangeCooldown = 60;

describe('Profile: cooldown', () => {
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
      profileArgs: {
        profileChangeCooldown
      }
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

  describe('Change consensus respect cooldown', async () => {
    before(async () => {
      await network.provider.send('hardhat_setCoinbase', [validatorCandidates[0].consensusAddr.address]);
      await validatorContract.connect(validatorCandidates[0].consensusAddr).submitBlockReward({value: 10_000});

      snapshotId = await network.provider.send('evm_snapshot');
    })

    after(async () => {
      const latestTimestamp = await getLastBlockTimestamp();
      await network.provider.send('evm_setNextBlockTimestamp', [latestTimestamp + profileChangeCooldown]);
    })

    it('Should the Profile can change C1 to C2', async () => {
      let profile : CandidateProfileStruct;
      profile = await profileContract.getId2Profile(validatorCandidates[0].consensusAddr.address);
      expect(profile.admin).eq(validatorCandidates[0].poolAdmin.address);
      expect(profile.treasury).eq(validatorCandidates[0].poolAdmin.address);
      expect(profile.consensus).eq(validatorCandidates[0].consensusAddr.address);

      let newConsensus = signers[signers.length - 1];
      let tx = await profileContract.connect(validatorCandidates[0].poolAdmin).changeConsensusAddr(validatorCandidates[0].cid.address, newConsensus.address);
      await expect(tx).emit(profileContract, "ProfileAddressChanged").withArgs(validatorCandidates[0].consensusAddr.address, RoleAccess.CONSENSUS, newConsensus.address);
      validatorCandidates[0].consensusAddr = newConsensus;
    });

    it('Should the Profile cannot change C2 to C3 when in cooldown', async () => {
      let newConsensus = signers[signers.length - 2];
      await expect(profileContract.connect(validatorCandidates[0].poolAdmin).changeConsensusAddr(validatorCandidates[0].cid.address, newConsensus.address))
        .revertedWithCustomError(profileContract, "ErrProfileChangeCooldownNotEnded");
    });

    it('Should the Profile cannot change C2 to C3 when cooldown passed', async () => {
      const latestTimestamp = await getLastBlockTimestamp();
      await network.provider.send('evm_setNextBlockTimestamp', [latestTimestamp + profileChangeCooldown]);

      let newConsensus = signers[signers.length - 2];
      let tx = await profileContract.connect(validatorCandidates[0].poolAdmin).changeConsensusAddr(validatorCandidates[0].cid.address, newConsensus.address);
      await expect(tx).emit(profileContract, "ProfileAddressChanged").withArgs(validatorCandidates[0].cid.address, RoleAccess.CONSENSUS, newConsensus.address);
      validatorCandidates[0].consensusAddr = newConsensus;
    });
  });

  describe('Change admin respect cooldown', async () => {
    let newAdmin: SignerWithAddress;

    before(async () => {
      await network.provider.send('hardhat_setCoinbase', [validatorCandidates[0].consensusAddr.address]);
    });

    after(async () => {
      const latestTimestamp = await getLastBlockTimestamp();
      await network.provider.send('evm_setNextBlockTimestamp', [latestTimestamp + profileChangeCooldown]);
    });

    it('Should the Profile can change A1 to A2', async () => {
      newAdmin = signers[signers.length - 3];
      let tx = await profileContract.connect(validatorCandidates[0].poolAdmin).changeAdminAddr(validatorCandidates[0].cid.address, newAdmin.address);
      await expect(tx).emit(profileContract, "ProfileAddressChanged").withArgs(validatorCandidates[0].cid.address, RoleAccess.CANDIDATE_ADMIN, newAdmin.address);
      validatorCandidates[0].poolAdmin = newAdmin;
    });

    it('Should the Profile cannot change A2 to A3 when in cooldown', async () => {
      newAdmin = signers[signers.length - 4];
      await expect(profileContract.connect(validatorCandidates[0].poolAdmin).changeAdminAddr(validatorCandidates[0].cid.address, newAdmin.address))
        .revertedWithCustomError(profileContract, "ErrProfileChangeCooldownNotEnded");
    });

    it('Should the Profile cannot change C1 to C2 when in cooldown', async () => {
      await expect(profileContract.connect(validatorCandidates[0].poolAdmin).changeConsensusAddr(validatorCandidates[0].cid.address, newAdmin.address))
        .revertedWithCustomError(profileContract, "ErrProfileChangeCooldownNotEnded");
    });

    it('Should the Profile cannot change A2 to A3 when cooldown passed', async () => {
      const latestTimestamp = await getLastBlockTimestamp();
      await network.provider.send('evm_setNextBlockTimestamp', [latestTimestamp + profileChangeCooldown]);

      let tx = await profileContract.connect(validatorCandidates[0].poolAdmin).changeAdminAddr(validatorCandidates[0].cid.address, newAdmin.address);
      await expect(tx).emit(profileContract, "ProfileAddressChanged").withArgs(validatorCandidates[0].cid.address, RoleAccess.CANDIDATE_ADMIN, newAdmin.address);
      validatorCandidates[0].poolAdmin = newAdmin;
    });
  });

  describe('Change pubkey respect cooldown', async () => {
    before(async () => {
      await network.provider.send('hardhat_setCoinbase', [validatorCandidates[0].consensusAddr.address]);
    })

    it('Should the Profile can change P1 to P2', async () => {
      let tx = await profileContract.connect(validatorCandidates[0].poolAdmin).changePubkey(validatorCandidates[0].cid.address, generateSamplePubkey(), "0x");
      await expect(tx).emit(profileContract, "PubkeyChanged").withArgs(validatorCandidates[0].cid.address, anyValue);
    });

    it('Should the Profile cannot change P2 to P3 when in cooldown', async () => {
      await expect(profileContract.connect(validatorCandidates[0].poolAdmin).changePubkey(validatorCandidates[0].cid.address, generateSamplePubkey(), "0x"))
        .revertedWithCustomError(profileContract, "ErrProfileChangeCooldownNotEnded");
    });

    it('Should the Profile cannot change A2 to A3 when cooldown passed', async () => {
      const latestTimestamp = await getLastBlockTimestamp();
      await network.provider.send('evm_setNextBlockTimestamp', [latestTimestamp + profileChangeCooldown]);

      let tx = await profileContract.connect(validatorCandidates[0].poolAdmin).changePubkey(validatorCandidates[0].cid.address, generateSamplePubkey(), "0x");
      await expect(tx).emit(profileContract, "PubkeyChanged").withArgs(validatorCandidates[0].cid.address, anyValue);
    });
  });

});
