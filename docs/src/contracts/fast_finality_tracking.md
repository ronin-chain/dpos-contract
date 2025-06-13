# Fast Finality Tracking

The `FastFinalityTracking` contract is responsible for tracking and scoring validator performance based on their participation in finalizing blocks. This mechanism ensures the reliability of validators by incentivizing active participation and maintaining a secure and efficient network.

---

## Key Responsibilities

1. **Tracking Finality Votes**:
   - Records votes submitted by validators for block finality.
   - Keeps a count of finality votes (`qcVoteCount`) for each validator in each epoch.

2. **Scoring Validators**:
   - Assigns scores to validators based on the quality of their finality votes and their normalized stake values.
   - Scores are calculated dynamically for each epoch to reflect validator performance accurately.

3. **Normalizing Stake Data**:
   - Ensures fair scoring by normalizing staking amounts across all validators.
   - Applies a pivot-based normalization to cap excessive stakes and balance scoring metrics.

4. **Integration with Epochs and Periods**:
   - Operates on an epoch-based system to ensure timely and accurate tracking of validator actions.
   - Normalized data is updated per period for consistent calculations.

---

## Workflow

### 1. **Recording Finality Votes**

- The `recordFinality` function is called by the block producer (via `block.coinbase`) once per block.
- Validators who voted for block finality are recorded.
- Scores are updated for each validator based on:
  - Their normalized stake.
  - The total normalized stake of voters.

### 2. **Normalization of Stake Values**

- Stake values are normalized using the `inplaceFindNormalizedSumAndPivot` function from `LibArray`:
  - Excessively large stakes are capped to prevent unfair advantages.
  - The normalized stake values are stored for future calculations.

### 3. **Scoring Validators**

- The scoring formula accounts for:
  - Total stake of the validator (including self-stake and delegator stake amounts).
  - The validator's normalized stake.
  - The total normalized stake of voters.
  - The ratio of votes cast to the total possible votes.
- Scores reflect the contribution of each validator to the block finality process.

### 4. **Epoch-Based Tracking**

- Votes and scores are tracked for each epoch.
- The `epochOf` function from the `RoninValidatorSet` contract is used to determine the current epoch based on the block number.

---

## Data Structure

### Tracking Records

- **`_tracker`**:
  - Maps each epoch to a list of records for validators.
  - Each record includes:
    - `qcVoteCount`: The number of finality votes cast by the validator.
    - `score`: The cumulative score for the validator in the epoch.

### Normalized Data

- **`_normalizedData`**:
  - Stores normalized stake values for each validator in a period.
  - Includes:
    - `normalizedStake`: A mapping of validator IDs to their normalized stake values.
    - `normalizedSum`: The total normalized stake in the period.

---
