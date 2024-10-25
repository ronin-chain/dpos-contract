// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17 <0.9.0;

import "./Profile.base.unit.t.sol";

contract Profile_Concrete_Unit_Test is Profile_Base_Unit_Test {
  function testConcrete_RevertWhen_ChangePubkey() external {
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

  function testConcrete_RevertWhen_ApplyValidatorCandidate() external {
    _profile.setVerificationFailed(true);

    vm.startPrank(_staking);
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

  function testConcrete_RevertWhen_ChangePubkeyCooldownNotEnded() external {
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

  function testConcrete_ArePublicKeysRegistered() external {
    vm.startPrank(_staking);

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
