// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IDPoSStakingMigration
/// @notice Interface for the DPoS staking migration contract that manages the transition
///         from legacy DPoS staking to the new StakingManager system.
interface IDPoSStakingMigration {
    /// @dev Error of pool revoking timestamp not reach.
    error ErrPoolRevokingTimestampNotReach(address poolId, uint256 revokingTimestamp, uint256 blockTimestamp);
    /// @dev Error of L2 migration is not completed.
    error ErrL2MigrationNotCompleted();

    /// @dev Emitted when the migration is triggered.
    event MigrationTriggered(address indexed by);

    /// @dev Emitted when the L2 migration is completed.
    event L2MigrationStatusUpdated(address indexed by, bool status);

    /// @dev Emitted when a pool is deprecated.
    event PoolDeprecated(address indexed poolId);

    /// @notice Initializes the migration contract to version 5.
    /// @dev Sets up the StakingManager reference and grants MIGRATOR_ROLE.
    /// @param stakingManager Address of the new StakingManager contract.
    /// @param migrator Address that will receive the MIGRATOR_ROLE.
    function initializeV5(address stakingManager, address migrator) external;

    /// @notice Triggers the migration process, preventing new stakes/delegations.
    /// @dev Deposits the entire contract balance into StakingManager and sets migration flag.
    ///      Can only be called by an address with MIGRATOR_ROLE.
    function triggerMigration() external;

    /// @notice Manually deprecates a pool.
    /// @dev Pool admin must request renounce first and must pass revoking timestamp.
    /// @param poolId The ID of the pool to deprecate.
    function execRenounceAndDeprecatePool(address poolId) external;

    /// @notice Sets the L2 migration status.
    /// @dev Can only be called by an address with MIGRATOR_ROLE.
    /// @param status The status of the L2 migration.
    function setL2Migrated(bool status) external;

    /// @notice Returns the status of the L2 migration.
    /// @dev Can only be called by an address with MIGRATOR_ROLE.
    /// @return The status of the L2 migration.
    function isL2Migrated() external view returns (bool);
}
