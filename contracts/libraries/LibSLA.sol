// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

/**
 * @title RandomRequest
 * @dev A struct representing a random request.
 */
struct RandomRequest {
  // The period of the request.
  uint256 period;
  // The previous beacon value.
  uint256 prevBeacon;
  // The chain ID of the request.
  uint256 chainId;
  // The address that emits the request.
  address verifyingContract;
}

using LibSLA for RandomRequest global;

library LibSLA {
  /**
   * @dev Hashes the random request.
   */
  function hash(RandomRequest memory req) internal pure returns (bytes32) {
    return keccak256(abi.encode(req.period, req.prevBeacon, req.chainId, req.verifyingContract));
  }

  /**
   * @dev Calculates the proof seed
   */
  function calcProofSeed(RandomRequest memory req, bytes32 keyHash) internal pure returns (uint256) {
    return uint256(keccak256(abi.encode(req.period, req.prevBeacon, req.chainId, req.verifyingContract, keyHash)));
  }

  /**
   * @dev Calculates the key hash from public keys.
   */
  function calcKeyHash(uint256[2] memory publicKeys) internal pure returns (bytes32) {
    return keccak256(abi.encode(publicKeys));
  }
}
