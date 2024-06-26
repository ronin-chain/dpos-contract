import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { Instance, ProposalSegmentArguments, defaultSegment, explorerUrl, proxyInterface } from '../upgradeUtils';
import { VoteType } from '../../script/proposal';
import { roninchainNetworks, stakingVestingConfig } from '../../configs/config';
import { network } from 'hardhat';
import {
  Maintenance__factory,
  Profile__factory,
  RoninTrustedOrganization__factory,
  RoninValidatorSet__factory,
  Staking__factory,
} from '../../types';
import { ProposalDetailStruct } from '../../types/GovernanceAdmin';
import { Address } from 'hardhat-deploy/dist/types';

const deploy = async ({ getNamedAccounts, deployments, ethers }: HardhatRuntimeEnvironment) => {
  if (!roninchainNetworks.includes(network.name!)) {
    return;
  }

  const { execute } = deployments;
  let { governor } = await getNamedAccounts(); // NOTE: Should double check the `governor` account in the `hardhat.config.ts` file
  console.log('Governor:', governor);

  const allDeployments: Instance = {
    RoninGovernanceAdmin: await deployments.get('RoninGovernanceAdmin'),
    RoninValidatorSetProxy: await deployments.get('RoninValidatorSetProxy'),
    ProfileProxy: await deployments.get('ProfileProxy'),
    StakingProxy: await deployments.get('StakingProxy'),
    SlashIndicatorProxy: await deployments.get('SlashIndicatorProxy'),
    MaintenanceProxy: await deployments.get('MaintenanceProxy'),
    RoninTrustedOrganizationProxy: await deployments.get('RoninTrustedOrganizationProxy'),
    StakingVestingProxy: await deployments.get('StakingVestingProxy'),
    FastFinalityTrackingProxy: await deployments.get('FastFinalityTrackingProxy'),
    RoninBridgeManager: await deployments.get('RoninBridgeManager'),

    RoninValidatorSetLogic: await deployments.get('RoninValidatorSetLogic'),
    ProfileLogic: await deployments.get('ProfileLogic'),
    StakingLogic: await deployments.get('StakingLogic'),
    SlashIndicatorLogic: await deployments.get('SlashIndicatorLogic'),
    MaintenanceLogic: await deployments.get('MaintenanceLogic'),
    RoninTrustedOrganizationLogic: await deployments.get('RoninTrustedOrganizationLogic'),
    StakingVestingLogic: await deployments.get('StakingVestingLogic'),
    FastFinalityTrackingLogic: await deployments.get('FastFinalityTrackingLogic'),
  };

  //      Upgrade DPoS Contracts
  //      See `test/foundry/forking/REP-004/ChangeConsensusAddress.t.sol`
  let proposalSegments = await upgradeDPoSContractSetProposalPart(allDeployments);

  console.log(proposalSegments);

  // return;

  //////////////////////////////////////////
  //          Propose the proposal
  //////////////////////////////////////////
  const blockNumBefore = await ethers.provider.getBlockNumber();
  const blockBefore = await ethers.provider.getBlock(blockNumBefore);
  const timestampBefore = blockBefore.timestamp;
  const proposalExpiryTimestamp = timestampBefore + 3600 * 24 * 10; // expired in 10 days

  const tx = await execute(
    'RoninGovernanceAdmin',
    { from: governor, log: true },
    'proposeProposalForCurrentNetwork',
    proposalExpiryTimestamp, // expiryTimestamp
    [...proposalSegments.map((_) => _.target)], // targets
    [...proposalSegments.map((_) => _.value)], // values
    [...proposalSegments.map((_) => _.data)], // datas
    [...proposalSegments.map((_) => _.gasAmount)], // gasAmounts
    VoteType.For // ballot type
  );
  deployments.log(`${explorerUrl[network.name!]}/tx/${tx.transactionHash}`);
};

async function upgradeDPoSContractSetProposalPart(instance: Instance): Promise<ProposalSegmentArguments[]> {
  let segments: ProposalSegmentArguments[] = [];
  // upgrade `Profile` and bump to V2
  segments.push({
    ...defaultSegment,
    gasAmount: 15_000_000,
    target: instance.ProfileProxy!.address,
    data: proxyInterface.encodeFunctionData('upgradeToAndCall', [
      instance.ProfileLogic!.address,
      new Profile__factory().interface.encodeFunctionData('initializeV2', [
        instance.StakingProxy!.address,
        instance.RoninTrustedOrganizationProxy?.address,
      ]),
    ]),
  });

  // upgrade `Staking` and bump to V3
  segments.push({
    ...defaultSegment,
    target: instance.StakingProxy!.address,
    data: proxyInterface.encodeFunctionData('upgradeToAndCall', [
      instance.StakingLogic!.address,
      new Staking__factory().interface.encodeFunctionData('initializeV3', [instance.ProfileProxy!.address]),
    ]),
  });

  // upgrade `RoninValidatorSet` and bump to V4
  segments.push({
    ...defaultSegment,
    target: instance.RoninValidatorSetProxy!.address,
    data: proxyInterface.encodeFunctionData('upgradeToAndCall', [
      instance.RoninValidatorSetLogic?.address,
      new RoninValidatorSet__factory().interface.encodeFunctionData('initializeV4', [instance.ProfileProxy!.address]),
    ]),
  });

  // upgrade `Maintenance` and bump to V3
  segments.push({
    ...defaultSegment,
    target: instance.MaintenanceProxy!.address,
    data: proxyInterface.encodeFunctionData('upgradeToAndCall', [
      instance.MaintenanceLogic!.address,
      new Maintenance__factory().interface.encodeFunctionData('initializeV3', [instance.ProfileProxy!.address]),
    ]),
  });

  // upgrade `SlashIndicator` and bump to V3
  segments.push({
    ...defaultSegment,
    target: instance.SlashIndicatorProxy!.address,
    data: proxyInterface.encodeFunctionData('upgradeTo', [instance.SlashIndicatorLogic!.address]),
  });

  // upgrade `RoninTrustedOrganization` and bump to V2
  segments.push({
    ...defaultSegment,
    target: instance.RoninTrustedOrganizationProxy!.address,
    data: proxyInterface.encodeFunctionData('upgradeToAndCall', [
      instance.RoninTrustedOrganizationLogic!.address,
      new RoninTrustedOrganization__factory().interface.encodeFunctionData('initializeV2', [
        instance.ProfileProxy?.address,
      ]),
    ]),
  });

  return segments;
}

// yarn hardhat deploy --tags 230231109__ProposalOnRoninChain__V0_7_0 --network ronin-testnet
deploy.tags = ['230231109__ProposalOnRoninChain__V0_7_0'];

export default deploy;
