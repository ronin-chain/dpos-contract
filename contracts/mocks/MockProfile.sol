// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./MockPrecompile.sol";
import "../ronin/slash-indicator/SlashIndicator.sol";
import "../interfaces/validator/IRoninValidatorSet.sol";
import "../ronin/profile/Profile.sol";

contract MockProfile is Profile {
  bool internal _verificationFailed;

  function addNewProfile(
    CandidateProfile memory profile
  ) external onlyAdmin {
    CandidateProfile storage _profile = _id2Profile[profile.id];
    if (_profile.id != address(0)) revert ErrExistentProfile();
    _addNewProfile(_profile, profile);
  }

  function setVerificationFailed(
    bool _failed
  ) external {
    _verificationFailed = _failed;
  }

  function _pcVerifyBLSPublicKey(
    bytes calldata, /*publicKey*/
    bytes calldata /*proofOfPossession*/
  ) internal view override returns (bool) {
    return !_verificationFailed;
  }
}
