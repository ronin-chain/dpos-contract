// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17 <0.9.0;

import { Test } from "forge-std/Test.sol";

import { TransparentUpgradeableProxyV2 } from "src/extensions/TransparentUpgradeableProxyV2.sol";
import { IProfile } from "src/interfaces/IProfile.sol";
import { MockProfile } from "src/mocks/MockProfile.sol";
import { TConsensus } from "src/udvts/Types.sol";
import { MockValidatorSet } from "test/foundry/mocks/MockValidatorSet.sol";

abstract contract Profile_Base_Unit_Test is Test {
  MockProfile internal _profile;
  MockValidatorSet internal _validatorSet;
  address internal _id = makeAddr("default-id");
  address internal _proxyAdmin = makeAddr("proxy-admin");
  address internal _staking = makeAddr("staking");
  address internal _validatorAdmin = makeAddr("default-admin");
  address internal _zkRollupManager = makeAddr("zk-rollup-manager");
  bytes32 constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

  function setUp() public virtual {
    _validatorSet = new MockValidatorSet();

    MockProfile _profileLogic = new MockProfile();
    _profile = MockProfile(address(new TransparentUpgradeableProxyV2(address(_profileLogic), _proxyAdmin, "")));
    _profile.initialize(address(_validatorSet));
    _profile.initializeV2(_staking, address(0));
    _profile.initializeV3(10);
    _profile.initializeV4(_zkRollupManager);

    _profile.exposed_addNewProfile(
      IProfile.CandidateProfile({
        id: _id,
        consensus: TConsensus.wrap(_id),
        admin: _validatorAdmin,
        treasury: payable(_id),
        __reservedGovernor: address(0),
        vrfKeyHash: 0x0,
        pubkey: "",
        profileLastChange: 0,
        oldPubkey: "",
        oldConsensus: TConsensus.wrap(address(0)),
        registeredAt: 0,
        vrfKeyHashLastChange: 0,
        rollupId: 0,
        aggregator: address(0),
        sequencer: address(0)
      })
    );

    vm.stopPrank();
  }
}
