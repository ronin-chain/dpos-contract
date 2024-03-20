// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17 <0.9.0;

import { Base_Test } from "@ronin/test/Base.t.sol";

import { MockProfile } from "@ronin/contracts/mocks/MockProfile.sol";
import { MockValidatorSet } from "@ronin/test/mocks/MockValidatorSet.sol";
import { IProfile } from "@ronin/contracts/interfaces/IProfile.sol";
import { TConsensus } from "@ronin/contracts/udvts/Types.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";

contract Profile_Unit_Test is Base_Test {
  MockProfile internal _profile;
  MockValidatorSet internal _validatorSetContract;
  address internal immutable _stakingContract = address(0x10000);
  address internal immutable _validatorAdmin = address(0x20001);
  bytes32 constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

  function setUp() public virtual {
    _validatorSetContract = new MockValidatorSet();

    MockProfile _profileLogic = new MockProfile();
    _profile = MockProfile(address(new TransparentUpgradeableProxyV2(address(_profileLogic), address(1), "")));
    _profile.initialize(address(_validatorSetContract));
    _profile.initializeV2(_stakingContract, address(0));
    _profile.initializeV3(10);

    vm.startPrank(address(1));

    TransparentUpgradeableProxyV2 _proxy = TransparentUpgradeableProxyV2(payable(address(_profile)));
    _proxy.functionDelegateCall(
      abi.encodeWithSelector(
        MockProfile.addNewProfile.selector,
        IProfile.CandidateProfile({
          id: address(0x20000),
          consensus: TConsensus.wrap(address(0x20000)),
          admin: _validatorAdmin,
          treasury: payable(address(0x20000)),
          __reservedGovernor: address(0),
          pubkey: "",
          profileLastChange: 0,
          oldPubkey: "",
          oldConsensus: TConsensus.wrap(address(0))
        })
      )
    );

    vm.stopPrank();
  }

  function test_RevertWhen_ChangePubkey() external {
    IProfile.CandidateProfile memory _validatorProfile;

    _profile.setVerificationFailed(true);

    vm.startPrank(_validatorAdmin);
    vm.warp(block.timestamp + 11);

    vm.expectRevert(abi.encodeWithSelector(IProfile.ErrInvalidProofOfPossession.selector, "0xaa", ""));
    _profile.changePubkey(address(0x20000), "0xaa", "");

    _profile.setVerificationFailed(false);

    _profile.changePubkey(address(0x20000), "0xbb", "");
    _validatorProfile = _profile.getId2Profile(address(0x20000));
    assertEq(_validatorProfile.pubkey, "0xbb");

    vm.stopPrank();
  }

  function test_RevertWhen_ApplyValidatorCandidate() external {
    _profile.setVerificationFailed(true);

    vm.startPrank(_stakingContract);
    vm.expectRevert(abi.encodeWithSelector(IProfile.ErrInvalidProofOfPossession.selector, "0xcc", ""));
    _profile.execApplyValidatorCandidate({
      admin: address(0x30000),
      id: address(0x30001),
      treasury: address(0x30000),
      pubkey: "0xcc",
      proofOfPossession: ""
    });

    _profile.setVerificationFailed(false);
    _profile.execApplyValidatorCandidate({
      admin: address(0x30000),
      id: address(0x30001),
      treasury: address(0x30000),
      pubkey: "0xcc",
      proofOfPossession: ""
    });

    vm.stopPrank();
  }

  function test_RevertWhen_ChangePubkeyCooldownNotEnded() external {
    vm.startPrank(_validatorAdmin);
    vm.warp(block.timestamp + 11);

    _profile.changePubkey(address(0x20000), "0xaa", "");

    vm.expectRevert(IProfile.ErrProfileChangeCooldownNotEnded.selector);
    _profile.changePubkey(address(0x20000), "0xbb", "");

    vm.warp(block.timestamp + 11);
    _profile.changePubkey(address(0x20000), "0xbb", "");

    IProfile.CandidateProfile memory _validatorProfile = _profile.getId2Profile(address(0x20000));
    assertEq(_validatorProfile.oldPubkey, "0xaa");
    assertEq(_validatorProfile.pubkey, "0xbb");

    vm.stopPrank();
  }

  function test_ArePublicKeysRegistered() external {
    vm.startPrank(_stakingContract);

    _profile.setVerificationFailed(false);
    _profile.execApplyValidatorCandidate({
      admin: address(0x30000),
      id: address(0x30001),
      treasury: address(0x30000),
      pubkey: "0xbb",
      proofOfPossession: ""
    });

    _profile.execApplyValidatorCandidate({
      admin: address(0x40000),
      id: address(0x40001),
      treasury: address(0x40000),
      pubkey: "0xcc",
      proofOfPossession: ""
    });

    bytes[][2] memory listOfPublicKey;
    listOfPublicKey[0] = new bytes[](1);
    listOfPublicKey[0][0] = "0xbb";

    assertEq(_profile.arePublicKeysRegistered(listOfPublicKey), true);

    listOfPublicKey[1] = new bytes[](1);
    listOfPublicKey[1][0] = "0xcc";
    assertEq(_profile.arePublicKeysRegistered(listOfPublicKey), true);

    bytes[][2] memory listOfPublicKey2;
    listOfPublicKey2[0] = new bytes[](1);
    listOfPublicKey2[0][0] = "0xaa";
    assertEq(_profile.arePublicKeysRegistered(listOfPublicKey2), false);

    vm.stopPrank();
  }
}
