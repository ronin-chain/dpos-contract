# Slash Indicator

---

## Overview

The Slash Indicator system enforces validator accountability by applying penalties for misbehavior or failure to meet network responsibilities. These penalties include slashing RON, jailing validators, and reducing rewards. Additionally, the system uses a **Credit Score** mechanism to incentivize good behavior and allow recovery from penalties. The system ensures network security and reliability by deterring harmful activities and encouraging validators to adhere to protocol rules.

---

## Credit Score System

### Overview

The **Credit Score** incentivizes validators to maintain high performance and provides a mechanism to bail out from penalties like jailing. This scoring system promotes fairness by allowing recovery while ensuring consistent participation in the network.

---

### Core Logic

#### 1. Credit Score Management

- **Earning Credit**:
  - Validators earn scores based on their performance in each period, excluding jailed or maintenance periods.
  - Scores are capped at a configurable maximum (`_maxCreditScore`).

- **Resetting Credit**:
  - Scores can be reset by the system for specific validators when they are kicked-out when insufficient self-stake amount, renounced or emergency exit met revoking timestamp.

#### 2. Bailout Mechanism

- **Eligibility**:
  - Validators can use credit scores to bail out of jailing if they:
    - Have sufficient scores to cover the cost (`jailedEpochLeft * _bailOutCostMultiplier`).
    - Have not bailed out previously during the same period.

- **Bailout Execution**:
  - Once bailed out, the credit score is deducted by the cost of `jailedEpochLeft * _bailOutCostMultiplier` and the validator is unjailed and allowed to resume operations.
  - No further penalties apply, as rewards are already reduced at the point of slashing.

---

### Integration

- **RoninValidatorSet**:
  - Executes jailing, bailout, and unavailability indicator resets.
- **Maintenance Contract**:
  - Tracks maintenance periods, affecting credit score calculations.

---

## Slash Unavailability

### Overview

The **Slash Unavailability** penalizes validators for failing to participate in block production.

---

### Core Logic

1. **Unavailability Tracking**:
   - If a block producer fails to produce blocks during their assigned round and a lower-priority block producer steps in to produce them, the assigned block producer can be subject to slashing.
   - Prevents redundant slashes within the same block.

2. **Slashing Tiers**:
   - **Tier 1**: Loss of rewards for mining reward for exceeding the first threshold.
   - **Tier 2**: Loss of rewards for mining reward and deducting self-stake and temporary jailing but allowing bail out.
   - **Tier 3**: Severe penalties if bail-outed once in the current period, loss of mining rewards, deducting self-stake and jailed and cannot bail out.

3. **Penalty Execution**:
   - Enforced via the `RoninValidatorSet` contract.
   - Includes RON deduction, jailing, and progressive penalties.

---

### Configuration

- Thresholds, slashing amounts, and jail durations are dynamically configurable via `setUnavailabilitySlashingConfigs`.

---

## Slash Double Sign

### Overview

The **Slash Double Sign** module addresses validators signing multiple blocks at the same height, which compromises consensus.

---

### Core Logic

1. **Governance Voting**:
   - Requires evidence validation and approval by governing validators before penalties are applied.

2. **Penalties**:
   - Slashing of RON and jailing until a specified block.
   - No bailout is allowed for double-signing violations.

---

### Key Features

- **Governance Oversight**:
  - Ensures penalties are applied only after governing validator approval.
- **Replay Protection**:
  - Prevents duplicate slashing for the same evidence.

---

## Slash Fast Finality

### Overview

The **Slash Fast Finality** penalizes validators who sign for finality on conflicting headers at the same height.

---

### Core Logic

- **Detection**:
  - Validates evidence of conflicting finality signatures using cryptographic verification.
- **Penalties**:
  - Includes RON slashing and jailing until a specific block.
  - Bailout is disallowed for fast finality violations.

---

## Slash Random Beacon

### Overview

The **Slash Random Beacon** module ensures validators fulfill their duty to submit random beacon values.

---

### Core Logic

- **Responsibility**:
  - Validators must submit beacon values during specific periods.
- **Penalties**:
  - RON slashing for non-compliance.
  - No jailing, and bailout is allowed.

---

## Comparisons Between Slash Types

| **Feature**       | **Unavailability**                 | **Double Sign**      | **Fast Finality**               | **Random Beacon**                 |
| ----------------- | ---------------------------------- | -------------------- | ------------------------------- | --------------------------------- |
| **Penalty**       | Slashing, jailing                  | Slashing, jailing    | Slashing, jailing               | Slashing                          |
| **Trigger**       | Missed blocks                      | Double-sign evidence | Conflicting finality signatures | Missing random beacon submissions |
| **Authorization** | Block Producer                     | Governance Voting    | Governor                        | System transaction                |
| **Bailout**       | Allowed Tier 2, Not allowed Tier 3 | Not allowed          | Not allowed                     | Not required                      |
| **Jailing**       | Yes (Tier 2/3)                     | Yes                  | Yes                             | No                                |

---

## Conclusion

The Slash Indicator system, coupled with the Credit Score module, provides a robust framework for maintaining validator accountability and network security. The combination of slashing, jailing, and scoring mechanisms ensures validators act responsibly while offering a path to recovery for occasional lapses in performance.

---
