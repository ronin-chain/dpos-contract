// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 as console } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";

import { TConsensus } from "@ronin/contracts/udvts/Types.sol";
import { Proposal, RoninMigration } from "script/RoninMigration.s.sol";
import { Contract } from "script/utils/Contract.sol";
import { DefaultNetwork } from "foundry-deployment-kit/utils/DefaultNetwork.sol";
import { DefaultContract } from "foundry-deployment-kit/utils/DefaultContract.sol";
import { BridgeTracking } from "@ronin/contracts/ronin/gateway/BridgeTracking.sol";
import { RoninTrustedOrganization } from "@ronin/contracts/multi-chains/RoninTrustedOrganization.sol";
import { BridgeReward } from "@ronin/contracts/ronin/gateway/BridgeReward.sol";
import { TransparentUpgradeableProxy, TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";

import { IRoninTrustedOrganization, RoninTrustedOrganization } from "@ronin/contracts/multi-chains/RoninTrustedOrganization.sol";
import { GovernanceAdmin, RoninGovernanceAdmin } from "@ronin/contracts/ronin/RoninGovernanceAdmin.sol";

abstract contract MikoConfig is RoninMigration {
  using StdStyle for *;

  bytes32 public constant $_IMPL_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
  bytes32 public constant $_ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
  bytes32 public constant MIGRATOR_ROLE = keccak256("MIGRATOR_ROLE");
  bytes32 public constant DEFAULT_ADMIN_ROLE = bytes32(0x00);

  string public constant MIGRATE_DATA_PATH = "script/data/cid_mainnet.json";

  /**
   * NOTE: Addresses that requires private keys
   */
  address public constant BAO_EOA_MAINNET = 0x4d58Ea7231c394d5804e8B06B1365915f906E27F; // op:

  // address public constant DEPLOYER = 0xFE490b68E64B190B415Bb92F8D2F7566243E6ea0; // Mainnet Shadow deployer address (FIXME: change to BAO's EOA when on mainnet)
  // address public constant BAO_EOA = 0x34825ac407c9817278629fdA290C85a82A753B03; // Mainnet Shadow Bao's EOA (FIXME: change to BAO's EOA when on mainnet)

  address public constant DEPLOYER = BAO_EOA_MAINNET; // Mainnet Shadow deployer address (FIXME: change to BAO's EOA when on mainnet)
  address public constant BAO_EOA = BAO_EOA_MAINNET; // Mainnet Shadow Bao's EOA (FIXME: change to BAO's EOA when on mainnet)
  address public constant ADMIN_TMP_BRIDGE_TRACKING = 0x25F7D5901ed7d397EC0758bb59717d6D623286A1; // op: [Mainnet][Bridge] Bridge Tracking Temp Admin (Doctor)
  address public constant STAKING_MIGRATOR = 0x555a4D1201DecF7d5C87EcF67B1f0b6430bED2Ed; // op: [Mainnet][DPoS] Staking Migrator
  address public constant SKY_MAVIS_GOVERNOR = 0xe880802580a1fbdeF67ACe39D1B21c5b2C74f059; // op:

  /**
   * Configs
   */
  address public constant ANDY_TREZOR = 0xEd4A9F48a62Fb6FdcfB45Bb00C9f61D1A436E58C; // Andy's Trezor
  address public constant TRUSTED_ORG_RECOVERY_LOGIC = 0x59646258Ec25CC329f5ce93223e0A50ccfA3e885;

  uint256 public constant PROPOSAL_DURATION = 14 days; // FIXME: `20 minutes` on mainnet shadow
  BridgeReward public constant DEPRECATED_BRIDGE_REWARD = BridgeReward(0x1C952D6717eBFd2E92E5f43Ef7C1c3f7677F007D);

  uint256 public constant PROFILE_PUBKEY_CHANGE_COOLDOWN = 7 days;

  TConsensus public constant STABLE_NODE_CONSENSUS = TConsensus.wrap(0x6E46924371d0e910769aaBE0d867590deAC20684);
  address public constant STABLE_NODE_GOVERNOR = 0x3C583c0c97646a73843aE57b93f33e1995C8DC80;
}
