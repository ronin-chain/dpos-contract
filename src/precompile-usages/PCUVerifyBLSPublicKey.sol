// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./PrecompiledUsage.sol";

abstract contract PCUVerifyBLSPublicKey is PrecompiledUsage {
  /// @dev Gets the address of the precompile of validating double sign evidence
  function precompileVerifyBLSPublicKeyAddress() public view virtual returns (address) {
    return address(0x6a);
  }

  /**
   * @dev Validates the proof of possession of BLS public key
   *
   * Note: The verify process is done by pre-compiled contract. This function is marked as
   * virtual for implementing mocking contract for testing purpose.
   */
  function _pcVerifyBLSPublicKey(
    bytes calldata publicKey,
    bytes calldata proofOfPossession
  ) internal view virtual returns (bool validPublicKey) {
    address smc = precompileVerifyBLSPublicKeyAddress();
    bool success = true;

    bytes memory payload =
      abi.encodeWithSignature("validateProofOfPossession(bytes,bytes)", publicKey, proofOfPossession);
    uint payloadLength = payload.length;
    uint[1] memory output;

    assembly {
      let payloadStart := add(payload, 0x20)
      if iszero(staticcall(gas(), smc, payloadStart, payloadLength, output, 0x20)) { success := 0 }

      if iszero(returndatasize()) { success := 0 }
    }

    if (!success) revert ErrCallPrecompiled();
    return (output[0] != 0);
  }
}
