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
}

using LibSLA for RandomRequest global;

library LibSLA {
  /**
   * @dev Hashes the random request.
   */
  function hash(RandomRequest memory req) internal pure returns (bytes32) {
    return keccak256(abi.encode(req.period, req.prevBeacon));
  }

  /**
   * @dev Calculates the proof seed
   */
  function calcProofSeed(RandomRequest memory req, bytes32 keyHash, address oracle) internal pure returns (uint256) {
    return uint256(keccak256(abi.encode(req.period, req.prevBeacon, keyHash, oracle)));
  }

  /**
   * @dev Calculates the key hash from public keys.
   */
  function calcKeyHash(uint256[2] memory publicKeys) internal pure returns (bytes32) {
    return keccak256(abi.encode(publicKeys));
  }
}
