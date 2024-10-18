// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IRoninGovernanceAdmin } from "@ronin/contracts/interfaces/IRoninGovernanceAdmin.sol";
import { IRoninValidatorSet } from "@ronin/contracts/interfaces/validator/IRoninValidatorSet.sol";
import { IRoninGatewayV3 } from "@ronin/contracts/interfaces/IRoninGatewayV3.sol";
import { IMainchainGatewayV3 } from "@ronin/contracts/interfaces/IMainchainGatewayV3.sol";
import { IMaintenance } from "@ronin/contracts/interfaces/IMaintenance.sol";
import { IBridgeTracking } from "@ronin/contracts/interfaces/bridge/IBridgeTracking.sol";
import { ISlashIndicator } from "@ronin/contracts/interfaces/slash-indicator/ISlashIndicator.sol";
import { IRoninTrustedOrganization } from "@ronin/contracts/interfaces/IRoninTrustedOrganization.sol";
import { IStaking } from "@ronin/contracts/interfaces/staking/IStaking.sol";
import { IStakingVesting } from "@ronin/contracts/interfaces/IStakingVesting.sol";
import { IFastFinalityTracking } from "@ronin/contracts/interfaces/IFastFinalityTracking.sol";
import { IBridgeTracking } from "@ronin/contracts/interfaces/bridge/IBridgeTracking.sol";
import { IBridgeReward } from "@ronin/contracts/interfaces/bridge/IBridgeReward.sol";
import { IBridgeSlash } from "@ronin/contracts/interfaces/bridge/IBridgeSlash.sol";
import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { MockPrecompile } from "@ronin/contracts/mocks/MockPrecompile.sol";
import { MappedTokenConsumer } from "@ronin/contracts/interfaces/consumers/MappedTokenConsumer.sol";
import { Token } from "@ronin/contracts/libraries/Token.sol";
import { Transfer } from "@ronin/contracts/libraries/Transfer.sol";

import { RoninValidatorSetTimedMigratorUpgrade } from "script/contracts/RoninValidatorSetTimedMigratorUpgrade.s.sol";
import { NotifiedMigratorUpgrade } from "script/contracts/NotifiedMigratorUpgrade.s.sol";
import { ProfileDeploy } from "script/contracts/ProfileDeploy.s.sol";
import { DefaultNetwork, RoninMigration } from "script/RoninMigration.s.sol";
import { Network } from "script/utils/Network.sol";
import { Contract } from "script/utils/Contract.sol";

contract Simulation__20231003_UpgradeREP002AndREP003_Base is RoninMigration, MappedTokenConsumer {
  using Transfer for *;

  IStaking internal _staking;
  IRoninGatewayV3 internal _roninGateway;
  IBridgeTracking internal _bridgeTracking;
  ISlashIndicator internal _slashIndicator;
  IRoninValidatorSet internal _validatorSet;
  IStakingVesting internal _stakingVesting;
  IRoninTrustedOrganization internal _trustedOrgs;
  IFastFinalityTracking internal _fastFinalityTracking;
  IRoninGovernanceAdmin internal _roninGovernanceAdmin;

  // new contracts
  IBridgeSlash internal _bridgeSlash;
  IBridgeReward internal _bridgeReward;
  IBridgeManager internal _roninBridgeManager;

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

  function _afterDepositForOnlyOnRonin(
    Transfer.Receipt memory
  ) internal virtual { }

  function run() public virtual {
    {
      address mockPrecompile = _deployLogic(Contract.MockPrecompile.key());
      vm.etch(address(0x68), mockPrecompile.code);
      vm.makePersistent(address(0x68));
    }

    _staking = IStaking(loadContract(Contract.Staking.key()));
    _roninGateway = IRoninGatewayV3(loadContract(Contract.RoninGatewayV3.key()));
    _bridgeTracking = IBridgeTracking(loadContract(Contract.BridgeTracking.key()));
    _slashIndicator = ISlashIndicator(loadContract(Contract.SlashIndicator.key()));
    _stakingVesting = IStakingVesting(loadContract(Contract.StakingVesting.key()));
    _validatorSet = IRoninValidatorSet(loadContract(Contract.RoninValidatorSet.key()));
    _trustedOrgs = IRoninTrustedOrganization(loadContract(Contract.RoninTrustedOrganization.key()));
    _fastFinalityTracking = IFastFinalityTracking(loadContract(Contract.FastFinalityTracking.key()));
    _roninGovernanceAdmin = IRoninGovernanceAdmin(loadContract(Contract.RoninGovernanceAdmin.key()));
    _roninBridgeManager = IBridgeManager(loadContract(Contract.RoninBridgeManager.key()));

    _depositCount = _hookSetDepositCount();
  }

  function _depositForOnBothChain(
    string memory userName
  ) internal {
    Account memory user = makeAccount(userName);
    vm.makePersistent(user.addr);
    vm.deal(user.addr, 1000 ether);

    Transfer.Request memory request =
      Transfer.Request(user.addr, address(0), Token.Info(Token.Standard.ERC20, 0, 1 ether));

    IMainchainGatewayV3 mainchainGateway =
      IMainchainGatewayV3(config.getAddress(Network.EthMainnet.key(), Contract.MainchainGatewayV3.key()));

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

  function _depositForOnlyOnRonin(
    string memory userName
  ) internal {
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
