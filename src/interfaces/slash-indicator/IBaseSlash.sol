// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IBaseSlash {
  enum SlashType {
    UNKNOWN,
    UNAVAILABILITY_TIER_1,
    UNAVAILABILITY_TIER_2,
    DOUBLE_SIGNING,
    BRIDGE_VOTING,
    BRIDGE_OPERATOR_MISSING_VOTE_TIER_1,
    BRIDGE_OPERATOR_MISSING_VOTE_TIER_2,
    UNAVAILABILITY_TIER_3,
    FAST_FINALITY,
    RANDOM_BEACON
  }

  /// @dev Error thrown when evidence has already been submitted.
  error ErrEvidenceAlreadySubmitted();

  /// @dev Error thrown when public key in evidence is not registered.
  error ErrUnregisteredPublicKey();

  /// @dev Emitted when the validator is slashed.
  event Slashed(address indexed cid, SlashType slashType, uint256 period);
}