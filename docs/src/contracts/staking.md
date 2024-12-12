# Staking Documentation

---

## Overview

The Staking module manages the network's core participation mechanism, allowing both validator candidates and delegators to stake RON, earn rewards, and contribute to the network's security and governance. This module includes distinct functionalities for **Candidate Staking** and **Delegator Staking**, each tailored to different roles within the ecosystem.

### Summary of Features

- **Candidate Staking**: Facilitates validator candidates to stake RON, apply for validator roles, and manage their staking pools.
- **Delegator Staking**: Enables participants to delegate RON to validators, withdraw or transfer stakes, and claim rewards.

---

## Candidate Staking

### Overview

The `CandidateStaking` module allows individuals to apply as validators, stake RON, and manage their staking pools. It governs the minimum requirements and operational guidelines for candidates aiming to become validators.

### Core Features

1. **Validator Application**:
   - Candidates must stake the minimum required amount and submit public keys, proof of possession, and commission rates.
   - Prevents admins of active pools from becoming candidates.

2. **Staking and Unstaking**:
   - Candidates can increase their stake to maintain their status.
   - Unstaking requires adherence to minimum thresholds and cooldown periods.

3. **Commission Rate Management**:
   - Allows candidates to set and adjust commission rates for delegators within configurable admin-defined limits.

4. **Pool Deprecation**:
   - Handles the transition when a candidate exits, redistributing unclaimed rewards and returning stakes to the admin.

5. **Emergency Exit and Renunciation**:
   - Enables candidates to renounce their validator roles or perform emergency exits to cease operations.

### Workflow

- **Application**: Candidates register using `applyValidatorCandidate`, providing necessary details and staking the required amount.
- **Staking**: Candidates call `stake` to increase their pool's total stake.
- **Unstaking**: Candidates use `unstake` to withdraw funds, observing cooldown and minimum stake requirements.
- **Commission Management**: Candidates can request commission rate updates using `requestUpdateCommissionRate`.
- **Deprecation**: Exiting candidates transfer stake and rewards to their admin via pool deprecation mechanisms.

### Configuration

- **Staking Requirements**:
  - Admins configure minimum staking amounts via `setMinValidatorStakingAmount`.
- **Commission Rates**:
  - Admin-defined limits control fairness and flexibility.

---

## Delegator Staking

### Overview

The `DelegatorStaking` module allows network participants to stake RON with validators, supporting the network while earning rewards. Delegators actively participate in governance and network security by contributing to validator pools.

### Core Features

1. **Delegation**:
   - Delegators stake RON with active validator pools to support the network.
   - Their stake contributes to the validator’s total staking amount, influencing their network role.

2. **Undelegation**:
   - Delegators can withdraw their stake, subject to cooldown periods and pool status.

3. **Redelegation**:
   - RON can be transferred between pools without unstaking, enabling flexibility in delegator support.

4. **Reward Claiming**:
   - Rewards earned by delegators are based on their stake and the pool's reward allocation.

5. **Reward Delegation**:
   - Delegators can reinvest their earned rewards directly into another pool.

### Workflow

- **Delegation**: Delegators call `delegate` to stake RON with a validator.
- **Undelegation**: Delegators call `undelegate` to withdraw their stake after passing validation checks.
- **Redelegation**: Delegators call `redelegate` to transfer their stake between pools.
- **Reward Claiming**: Rewards are claimed using `claimRewards`.
- **Reward Delegation**: Delegators call `delegateRewards` to reinvest their rewards into another pool.

### Configuration

- **Cooldown Periods**:
  - Admin-defined cooldown periods regulate staking, undelegation, and redelegation actions.

---

## Summary of Key Features

| Feature              | Candidate Staking                           | Delegator Staking                              |
| -------------------- | ------------------------------------------- | ---------------------------------------------- |
| Role                 | Validator Candidates                        | Network Participants                           |
| Staking              | Minimum required self-stake                 | Delegated RON with no minimum                  |
| Unstaking            | Cooldown periods, minimum balance enforced  | Cooldown periods for undelegation              |
| Rewards              | Receive rewards based on pool activity      | Earn proportional rewards from validator pools |
| Additional Functions | Commission rate management, emergency exits | Reward redelegation, flexible pool switching   |

---

## Integration

- **RoninValidatorSet**: Coordinates validator operations, including candidacy approval and commission rate updates.
- **Profile Contract**: Registers candidate profiles with cryptographic details.
- **BaseStaking**: Manages core staking balances and interactions for both candidates and delegators.
