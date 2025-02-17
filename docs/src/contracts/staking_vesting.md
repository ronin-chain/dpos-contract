# Staking Vesting

---

## Purpose

The `StakingVesting` contract manages staking rewards, including block producer bonuses and fast finality rewards. It is designed to handle dynamic reward mechanisms, supporting seamless upgrades and integration with REP-10 for enhanced reward distribution.

---

## Core Logic

### Reward Distribution

The contract allocates rewards for block producers and implements a fast finality reward mechanism. Fast finality rewards incentivize validators to contribute to consensus, enhancing network stability.

- Rewards are credited per block, calculated based on the configured bonus amounts for each block produced.
- The contract ensures rewards are sent only once per block to prevent duplicate distributions.

### REP-10 Integration

REP-10 introduces an upgraded reward mechanism for fast finality incentives. Its activation must occur at the start of a new period to ensure accurate reward distribution and consistency.

- **Activation Process**:
  - The contract tracks the predefined activation period (`_rep10ActivationPeriod`).
  - REP-10 is activated at the start of the first period that meets or exceeds this threshold.
- **Legacy Reward Percentage**:
  - Until REP-10 is activated, the contract uses the legacy fast finality reward percentage.
  - This ensures that rewards for the current period are distributed correctly under the pre-REP-10 configuration.
- **Transition**:
  - Upon activation, the reward percentage is updated to the REP-10 value (`_fastFinalityRewardPercentageREP10`), replacing the legacy percentage.

### Bonus Transfer Mechanism

The contract handles reward transfers securely and ensures uninterrupted operations even under constrained conditions.

- Bonus transfers are executed for block producers only when sufficient balance is available.
- If the contract lacks funds, the transfer fails gracefully without reverting the transaction, avoiding disruptions to the network.

---

## Upgrade and Configuration

The contract supports phased upgrades to introduce new features and refine reward mechanisms. Each initialization phase builds upon the previous configurations:

1. **Initial Setup**:
   - Configures block producer bonuses and validator contract addresses.
2. **REP-10 Activation**:
   - Adds dynamic updates for fast finality rewards, enabling more granular control.
3. **Backward Compatibility**:
   - Retains legacy configurations until new features are activated, ensuring smooth transitions.

---

---
