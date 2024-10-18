// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IRoninGovernanceAdmin } from "src/interfaces/IRoninGovernanceAdmin.sol";
import { IBridgeManager } from "src/interfaces/bridge/IBridgeManager.sol";
import { IMainchainGatewayV3 } from "src/interfaces/IMainchainGatewayV3.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin-v4/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { MappedTokenConsumer } from "src/interfaces/consumers/MappedTokenConsumer.sol";
import { RoninMigration } from "../RoninMigration.s.sol";
import { Contract } from "script/utils/Contract.sol";

contract Simulation__20231003_UpgradeREP002AndREP003_ETH is RoninMigration, MappedTokenConsumer {
  IRoninGovernanceAdmin internal _mainchainGovernanceAdmin;
  IMainchainGatewayV3 internal _mainchainGatewayV3;
  IBridgeManager internal _mainchainBridgeManager;

  function run() public virtual {
    _mainchainGatewayV3 = IMainchainGatewayV3(loadContract(Contract.MainchainGatewayV3.key()));
    _mainchainBridgeManager = IBridgeManager(loadContract(Contract.MainchainBridgeManager.key()));
    _mainchainGovernanceAdmin = IRoninGovernanceAdmin(loadContract(Contract.MainchainGovernanceAdmin.key()));

    _upgradeProxy(
      Contract.MainchainGatewayV3.key(),
      abi.encodeCall(IMainchainGatewayV3.initializeV2, (address(_mainchainBridgeManager)))
    );
    vm.startPrank(address(_mainchainGovernanceAdmin));
    TransparentUpgradeableProxy(payable(address(_mainchainGatewayV3))).changeAdmin(address(_mainchainBridgeManager));
    vm.stopPrank();
  }
}
