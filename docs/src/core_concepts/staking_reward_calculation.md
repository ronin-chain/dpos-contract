## Reward Calculation

---

### Overview

The `RewardCalculation` module determines and distributes staking rewards for participants in the Ronin network. It ensures rewards are calculated accurately based on staking contributions and updates user balances dynamically as staking amounts change. The reward mechanism incentivizes long-term staking and aligns validator and delegator interests.

---

### Core Logic

#### 1. Reward Accumulation

- **Period-Based Rewards**:
  - Rewards are calculated and accrued on a per-period basis for each staking pool.
  - The accumulated rewards per share (RPS) for a pool are updated at the end of each period.

- **Proportional Distribution**:
  - Rewards are distributed proportionally based on the staking amount.
  - Stakers earn rewards relative to their share of the total pool.

#### 2. User Reward Calculation

- **Debited Rewards**:
  - Tracks rewards earned by each user (`debited`) to prevent recalculation and ensure correctness.
- **New Rewards**:
  - New rewards are computed based on the difference in RPS since the last update and the user’s current staking amount.
- **Fallback Mechanism**:
  - If RPS for a period is unavailable, the last known RPS value is used to estimate rewards.

#### 3. Reward Syncing

- **Dynamic Updates**:
  - User rewards are recalculated whenever staking amounts change or at the end of a period.
- **Pool Shares Adjustment**:
  - Updates total pool shares to ensure consistent reward distribution.

#### 4. Reward Claiming

- Users can claim their accumulated rewards, which are settled and reset for the next period.
- Claiming rewards triggers updates to the user's reward state to prevent double claims.

---

### Workflow

1. **Reward Accumulation**:
   - Rewards for each staking pool are recorded at the end of every period.
   - The RPS is recalculated based on the total staking amount in the pool and the rewards allocated.

2. **Reward Syncing**:
   - User rewards are synced dynamically when their staking amount changes.
   - The system ensures rewards reflect the latest RPS and staking contributions.

3. **Reward Claiming**:
   - Users claim their rewards through a structured process:
     - Outstanding rewards are calculated based on the user’s current staking amount and RPS.
     - The rewards are transferred, and the user’s reward state is reset.

---

### Key Features

- **Accurate Proportional Rewards**:
  - Ensures rewards are distributed fairly based on individual contributions to the staking pool.
- **Dynamic Updates**:
  - User rewards and pool shares are updated in real-time as staking amounts change.

---

### Example: Reward Calculation Workflow

#### Scenario

- A staking pool (`Pool A`) has the following participants at the beginning of **Period 1**:
  - **User 1**: Staked 1,000 RON.
  - **User 2**: Staked 2,000 RON.
- The total reward allocated to `Pool A` for **Period 1** is 300 RON.

---

#### Step-by-Step Calculation

1. **Determine Total Staking Amount**:
   - **Pool A Total Staking** = 1,000 (User 1) + 2,000 (User 2) + 3,000 (Validator Self-Stake) = 6,000 RON.

2. **Calculate Reward Per Share (RPS)**:
   - **Reward Per Share (RPS)** = Total Reward / Total Staking = \\( \frac{300 \times 10^{18}}{6,000 \times 10^{18}} \\) = 0,05 per RON.

3. **Accumulate User Rewards**:
   - **User 1 Reward**:
     \\( 1,000 \times 0,05 = 50 \\ RON \\).
   - **User 2 Reward**:
     \\( 2,000 \times 0,05 = 100 \\ RON \\).

---

### Reward Claiming

4. **User 1 Claims Reward**:
   - The system calculates **User 1’s Reward** for **Period 1**:
     - Reward: 50 RON.
     - **Reward Transferred**: 50 RON.
   - **User 1's Reward Balance** is reset to 0.

---

### Period Transition

5. **New Stakes at Period 2**:
   - **User 1**: Adds 500 RON (Total: 1,500 RON).
   - **User 2**: Withdraws 1,000 RON (Total: 1,000 RON).

6. **Record Period 2 Rewards**:
   - **Pool A Total Staking**: 1,500 (User 1) + 1,000 (User 2) + 3,000 (Validator Self-Stake) = 5,500 RON.
   - New Reward Allocation: 500 RON.
   - **New Reward Per Share (RPS)**:  
     \\( \frac{500 \times 10^{18}}{5,500^{18}} = 0,09 \\) per RON.

7. **Calculate Updated Rewards**:
   - **User 1 Reward for Period 2**:  
     \\( 0 + 500 \times 0,09 = 45 \ \text{RON} \\).
   - **User 2 Reward for Period 2**:  
     \\( 100 + 1000 \times 0,09 = 190 \ \text{RON} \\).

---

### Summary of Rewards

| Period | User   | Staked Tokens | Reward Per Share (RPS) | Reward Earned (RON) |
| ------ | ------ | ------------- | ---------------------- | ------------------- |
| 1      | U1 | 1,000         | 0.05                   | 50                  |
| 1      | U2 | 2,000         | 0.05                   | 100                 |
| 2      | U1 | 1,500         | 0.09                   | 95                 |
| 2      | U2 | 1,000         | 0.09                   | 90                  |

---
