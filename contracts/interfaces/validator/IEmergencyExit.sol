// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IEmergencyExit {
  /// @dev Emitted when the fund is locked from an emergency exit request
  event EmergencyExitRequested(address indexed cid, uint256 lockedAmount);
  /// @dev Emitted when the fund that locked from an emergency exit request is transferred to the recipient.
  event EmergencyExitLockedFundReleased(address indexed cid, address indexed recipient, uint256 unlockedAmount);
  /// @dev Emitted when the fund that locked from an emergency exit request is failed to transferred back.
  event EmergencyExitLockedFundReleasingFailed(
    address indexed cid, address indexed recipient, uint256 unlockedAmount, uint256 contractBalance
  );

  /// @dev Emitted when the emergency exit locked amount is updated.
  event EmergencyExitLockedAmountUpdated(uint256 amount);
  /// @dev Emitted when the emergency expiry duration is updated.
  event EmergencyExpiryDurationUpdated(uint256 amount);

  /// @dev Error of already requested emergency exit before.
  error ErrAlreadyRequestedEmergencyExit();
  /// @dev Error thrown when the info of releasing locked fund not exist.
  error ErrLockedFundReleaseInfoNotFound(address cid);
  /// @dev Error thrown when the the locked fund of emergency exit might be recycled.
  error ErrLockedFundMightBeRecycled(address cid);

  /**
   * @dev Returns the amount of RON to lock from a consensus address.
   */
  function emergencyExitLockedAmount() external returns (uint256);

  /**
   * @dev Returns the duration that an emergency request is expired and the fund will be recycled.
   */
  function emergencyExpiryDuration() external returns (uint256);

  /**
   * @dev Sets the amount of RON to lock from a consensus address.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the event `EmergencyExitLockedAmountUpdated`.
   *
   */
  function setEmergencyExitLockedAmount(uint256 _emergencyExitLockedAmount) external;

  /**
   * @dev Sets the duration that an emergency request is expired and the fund will be recycled.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the event `EmergencyExpiryDurationUpdated`.
   *
   */
  function setEmergencyExpiryDuration(uint256 _emergencyExpiryDuration) external;

  /**
   * @dev Unlocks fund for emergency exit request.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the event `EmergencyExitLockedFundReleased` if the fund is successfully unlocked.
   * Emits the event `EmergencyExitLockedFundReleasingFailed` if the fund is failed to unlock.
   *
   */
  function execReleaseLockedFundForEmergencyExitRequest(address validatorId, address payable recipient) external;

  /**
   * @dev Fallback function of `IStaking-requestEmergencyExit`.
   *
   * Requirements:
   * - The method caller is staking contract.
   *
   */
  function execRequestEmergencyExit(address validatorId, uint256 secLeftToRevoke) external;
}
