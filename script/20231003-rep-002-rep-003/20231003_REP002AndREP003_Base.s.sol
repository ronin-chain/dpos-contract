// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninGovernanceAdmin } from "@ronin/contracts/ronin/RoninGovernanceAdmin.sol";
import { RoninGatewayV3 } from "@ronin/contracts/ronin/gateway/RoninGatewayV3.sol";
import { MainchainGatewayV3 } from "@ronin/contracts/mainchain/MainchainGatewayV3.sol";
import { Staking } from "@ronin/contracts/ronin/staking/Staking.sol";
import { Maintenance } from "@ronin/contracts/ronin/Maintenance.sol";
import { BridgeTracking } from "@ronin/contracts/ronin/gateway/BridgeTracking.sol";
import { SlashIndicator } from "@ronin/contracts/ronin/slash-indicator/SlashIndicator.sol";
import { RoninTrustedOrganization } from "@ronin/contracts/multi-chains/RoninTrustedOrganization.sol";
import { Staking } from "@ronin/contracts/ronin/staking/Staking.sol";
import { StakingVesting } from "@ronin/contracts/ronin/StakingVesting.sol";
import { FastFinalityTracking } from "@ronin/contracts/ronin/fast-finality/FastFinalityTracking.sol";
import { BridgeTracking } from "@ronin/contracts/ronin/gateway/BridgeTracking.sol";
import { BridgeReward } from "@ronin/contracts/ronin/gateway/BridgeReward.sol";
import { BridgeSlash } from "@ronin/contracts/ronin/gateway/BridgeSlash.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { MockPrecompile } from "@ronin/contracts/mocks/MockPrecompile.sol";
import { MappedTokenConsumer } from "@ronin/contracts/interfaces/consumers/MappedTokenConsumer.sol";
import { Token } from "@ronin/contracts/libraries/Token.sol";
import { Transfer } from "@ronin/contracts/libraries/Transfer.sol";

import {
  RoninValidatorSet,
  RoninValidatorSetTimedMigratorUpgrade
} from "script/contracts/RoninValidatorSetTimedMigratorUpgrade.s.sol";
import { NotifiedMigratorUpgrade } from "script/contracts/NotifiedMigratorUpgrade.s.sol";
import { ProfileDeploy } from "script/contracts/ProfileDeploy.s.sol";
import { DefaultNetwork, RoninMigration } from "script/RoninMigration.s.sol";
import { Network } from "script/utils/Network.sol";
import { Contract } from "script/utils/Contract.sol";

contract Simulation__20231003_UpgradeREP002AndREP003_Base is RoninMigration, MappedTokenConsumer {
  using Transfer for *;

  Staking internal _staking;
  RoninGatewayV3 internal _roninGateway;
  BridgeTracking internal _bridgeTracking;
  SlashIndicator internal _slashIndicator;
  RoninValidatorSet internal _validatorSet;
  StakingVesting internal _stakingVesting;
  RoninTrustedOrganization internal _trustedOrgs;
  FastFinalityTracking internal _fastFinalityTracking;
  RoninGovernanceAdmin internal _roninGovernanceAdmin;

  // new contracts
  BridgeSlash internal _bridgeSlash;
  BridgeReward internal _bridgeReward;
  RoninBridgeManager internal _roninBridgeManager;

  uint256 _depositCount;

  function _injectDependencies() internal virtual override {
    _setDependencyDeployScript(Contract.Profile.key(), address(new ProfileDeploy()));
  }

  function _hookSetDepositCount() internal pure virtual returns (uint256) {
    return 42127; // fork-block-number 28139075
  }

  function _hookPrankOperator() internal virtual returns (address) {
    return makeAccount("detach-operator-1").addr;
  }

  function _afterDepositForOnlyOnRonin(Transfer.Receipt memory) internal virtual { }

  function run() public virtual {
    {
      address mockPrecompile = _deployLogic(Contract.MockPrecompile.key());
      vm.etch(address(0x68), mockPrecompile.code);
      vm.makePersistent(address(0x68));
    }

    _staking = Staking(config.getAddressFromCurrentNetwork(Contract.Staking.key()));
    _roninGateway = RoninGatewayV3(config.getAddressFromCurrentNetwork(Contract.RoninGatewayV3.key()));
    _bridgeTracking = BridgeTracking(config.getAddressFromCurrentNetwork(Contract.BridgeTracking.key()));
    _slashIndicator = SlashIndicator(config.getAddressFromCurrentNetwork(Contract.SlashIndicator.key()));
    _stakingVesting = StakingVesting(config.getAddressFromCurrentNetwork(Contract.StakingVesting.key()));
    _validatorSet = RoninValidatorSet(config.getAddressFromCurrentNetwork(Contract.RoninValidatorSet.key()));
    _trustedOrgs =
      RoninTrustedOrganization(config.getAddressFromCurrentNetwork(Contract.RoninTrustedOrganization.key()));
    _fastFinalityTracking =
      FastFinalityTracking(config.getAddressFromCurrentNetwork(Contract.FastFinalityTracking.key()));
    _roninGovernanceAdmin =
      RoninGovernanceAdmin(config.getAddressFromCurrentNetwork(Contract.RoninGovernanceAdmin.key()));
    _roninBridgeManager = RoninBridgeManager(config.getAddressFromCurrentNetwork(Contract.RoninBridgeManager.key()));

    _depositCount = _hookSetDepositCount();
  }

  function _depositForOnBothChain(string memory userName) internal {
    Account memory user = makeAccount(userName);
    vm.makePersistent(user.addr);
    vm.deal(user.addr, 1000 ether);

    Transfer.Request memory request =
      Transfer.Request(user.addr, address(0), Token.Info(Token.Standard.ERC20, 0, 1 ether));

    MainchainGatewayV3 mainchainGateway =
      MainchainGatewayV3(config.getAddress(Network.EthMainnet.key(), Contract.MainchainGatewayV3.key()));

    // switch rpc to eth mainnet
    config.switchTo(Network.EthMainnet.key());

    address weth = address(mainchainGateway.wrappedNativeToken());
    MappedTokenConsumer.MappedToken memory token = mainchainGateway.getRoninToken(weth);

    Transfer.Receipt memory receipt = Transfer.Request(user.addr, weth, request.info).into_deposit_receipt(
      user.addr,
      mainchainGateway.depositCount(),
      token.tokenAddr,
      2020 // ronin-mainnet chainId
    );

    vm.prank(user.addr);
    mainchainGateway.requestDepositFor{ value: 1 ether }(request);

    // switch rpc to ronin mainnet
    config.switchTo(DefaultNetwork.RoninMainnet.key());

    address operator = _hookPrankOperator();
    vm.label(operator, "bridge-operator");
    vm.prank(operator);
    _roninGateway.depositFor(receipt);
  }

  function _depositForOnlyOnRonin(string memory userName) internal {
    Account memory user = makeAccount(userName);
    vm.makePersistent(user.addr);
    vm.deal(user.addr, 1000 ether);

    Transfer.Request memory request =
      Transfer.Request(user.addr, address(0), Token.Info(Token.Standard.ERC20, 0, 1 ether));

    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address roninToken = 0xc99a6A985eD2Cac1ef41640596C5A5f9F4E19Ef5;
    Transfer.Receipt memory receipt = Transfer.Request(user.addr, weth, request.info).into_deposit_receipt(
      user.addr,
      _depositCount++,
      roninToken,
      2020 // ronin-mainnet chainId
    );
    receipt.mainchain.chainId = 1;

    vm.prank(_hookPrankOperator());
    _roninGateway.depositFor(receipt);

    _afterDepositForOnlyOnRonin(receipt);
  }

  function _dummySwitchNetworks() internal {
    config.switchTo(Network.EthMainnet.key());
    config.switchTo(DefaultNetwork.RoninMainnet.key());
  }
}
