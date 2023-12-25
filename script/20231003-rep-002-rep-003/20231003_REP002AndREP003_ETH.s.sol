// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninGovernanceAdmin } from "@ronin/contracts/ronin/RoninGovernanceAdmin.sol";
import { MainchainBridgeManager } from "@ronin/contracts/mainchain/MainchainBridgeManager.sol";
import { MainchainGatewayV3 } from "@ronin/contracts/mainchain/MainchainGatewayV3.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { MappedTokenConsumer } from "@ronin/contracts/interfaces/consumers/MappedTokenConsumer.sol";
import { RoninMigration, DefaultNetwork } from "../RoninMigration.s.sol";
import { Contract } from "script/utils/Contract.sol";

contract Simulation__20231003_UpgradeREP002AndREP003_ETH is RoninMigration, MappedTokenConsumer {
  RoninGovernanceAdmin internal _mainchainGovernanceAdmin;
  MainchainGatewayV3 internal _mainchainGatewayV3;
  MainchainBridgeManager internal _mainchainBridgeManager;

  function run() public virtual {
    _mainchainGatewayV3 = MainchainGatewayV3(config.getAddressFromCurrentNetwork(Contract.MainchainGatewayV3.key()));
    _mainchainBridgeManager =
      MainchainBridgeManager(config.getAddressFromCurrentNetwork(Contract.MainchainBridgeManager.key()));
    _mainchainGovernanceAdmin =
      RoninGovernanceAdmin(config.getAddressFromCurrentNetwork(Contract.MainchainGovernanceAdmin.key()));

    _upgradeProxy(
      Contract.MainchainGatewayV3.key(),
      abi.encodeCall(MainchainGatewayV3.initializeV2, (address(_mainchainBridgeManager)))
    );
    vm.startPrank(address(_mainchainGovernanceAdmin));
    TransparentUpgradeableProxyV2(payable(address(_mainchainGatewayV3))).changeAdmin(address(_mainchainBridgeManager));
    vm.stopPrank();
  }
}
