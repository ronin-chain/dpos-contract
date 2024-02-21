// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 as console } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { JSONParserLib } from "lib/foundry-deployment-kit/lib/solady/src/utils/JSONParserLib.sol";

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

abstract contract MikoHelper is RoninMigration {
  using JSONParserLib for *;
  using StdStyle for *;

  bytes32 public constant $_IMPL_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
  bytes32 public constant MIGRATOR_ROLE = keccak256("MIGRATOR_ROLE");

  string public constant MIGRATE_DATA_PATH = "script/data/cid_mainnet.json";

  address public constant DEPLOYER = 0xFE490b68E64B190B415Bb92F8D2F7566243E6ea0; // Mainnet Shadow deployer address;
  address public constant BAO_EOA = 0x4d58Ea7231c394d5804e8B06B1365915f906E27F;
  address public constant ADMIN_TMP_BRIDGE_TRACKING = 0x25F7D5901ed7d397EC0758bb59717d6D623286A1; // [Mainnet][Bridge] Bridge Tracking Temp Admin
  address public constant STAKING_MIGRATOR = 0x555a4D1201DecF7d5C87EcF67B1f0b6430bED2Ed; // [Mainnet][DPoS] Staking Migrator
  address public constant TRUSTED_ORG_RECOVERY_LOGIC = 0x59646258Ec25CC329f5ce93223e0A50ccfA3e885;

  uint256 public constant PROPOSAL_DURATION = 20 minutes;
  BridgeReward public constant DEPRECATED_BRIDGE_REWARD = BridgeReward(0x1C952D6717eBFd2E92E5f43Ef7C1c3f7677F007D);

  uint256 public constant PROFILE_PUBKEY_CHANGE_COOLDOWN = 1 days;

  function _parseMigrateData(
    string memory path
  ) internal view returns (address[] memory poolIds, address[] memory admins, bool[] memory flags) {
    string memory raw = vm.readFile(path);
    JSONParserLib.Item memory data = raw.parse();
    uint256 size = data.size();
    console.log("size", size);

    poolIds = new address[](size);
    admins = new address[](size);
    flags = new bool[](size);

    for (uint256 i; i < size; ++i) {
      poolIds[i] = vm.parseAddress(data.at(i).at('"cid"').value().decodeString());
      admins[i] = vm.parseAddress(data.at(i).at('"admin"').value().decodeString());
      flags[i] = true;

      console.log("\nPool ID:".cyan(), vm.toString(poolIds[i]));
      console.log("Admin:".cyan(), vm.toString(admins[i]));
      console.log("Flags:".cyan(), flags[i]);
    }
  }
}
