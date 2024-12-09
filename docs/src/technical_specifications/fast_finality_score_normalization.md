# Fast Finality Tracking Score

The `FastFinalityTracking` score system is designed to evaluate and reward validators based on their contributions to achieving block finality in the Ronin network. This specification focuses on the methodology, particularly the normalization technique used to ensure fair scoring, as well as the implications for validator performance.

---

## Objectives

- Measure and reward validators for their contributions to block finality.
- Normalize staking data to balance scoring and prevent dominance by validators with excessively high stakes.
- Ensure a secure, efficient, and fair system for validators.

---

## Components

### 1. **Normalization Technique**

The normalization process adjusts validators' stake values to meet specific criteria:

- Maintain relative differences between stake values.
- Cap excessive stakes to ensure fairness.
- Use a pivot-based algorithm to determine the threshold for capping stake values.

#### Algorithm Overview

Given:

- An array of stake values \\( a \\): Descending-sorted stakes of validators.
- The sum of stakes \\( s \\): \\( s = \text{sum}(a) \\).
- The divisor \\( d \\): Maximum number of validators.
- An initial pivot \\( k \\): \\( k = s / d \\).

**Normalization Goals**:

1. Adjust stake values such that all \\( a[i] \leq k \\).
2. Maintain the relative order of \\( a \\) after adjustment.
3. Recalculate \\( k \\) iteratively based on the remaining values.

**Process**:

1. Initialize \\( k = s / d \\).
2. Iterate through the array \\( a \\):
   - Replace \\( a[i] > k \\) with \\( k \\).
   - Recalculate \\( s \\) and \\( k \\) using only unchanged values.
   - Repeat until \\( k \\) stabilizes and all \\( a[i] \leq k \\).

**Example**:

- Input:
  - \\( a = [100, 70, 20, 15, 3] \\)
  - \\( d = 3 \\)
- Calculation:
  - Step 1: \\( k = \text{sum}(a) / d = 208 / 3 = 69.3 \\).
  - Step 2: Adjust \\( a \\) to \\( [69, 69, 20, 15, 3] \\), recalculate \\( k = 177 / 3 = 59 \\).
  - Step 3: Adjust \\( a \\) to \\( [59, 59, 20, 15, 3] \\), \\( k \\) stabilizes at 59.

**Output**:

- Normalized stakes: \\( [59, 59, 20, 15, 3] \\).
- Normalized sum: \\( 114 \\).

---

### 2. **Tracking Finality Votes**

- A record of votes is maintained for each validator in every epoch.
- Votes are tracked in `_tracker`, which maps epochs to validators and their voting activity.

---

### 3. **Finality Score Calculation**

#### Formula

For a validator \\( v \\) in epoch \\( e \\):
$$
\text{score}_{v, e} = \frac{\text{normalizedStake}_v}{\text{totalVoterStake}} \times \frac{\text{totalVoterStake}^2}{\text{normalizedSum}^2}
$$

Where:

- \\( \text{normalizedStake}_v \\): Normalized stake of validator \\( v \\).
- \\( \text{totalVoterStake} \\): Sum of normalized stakes of all voters in the epoch.
- \\( \text{normalizedSum} \\): Total normalized stake across all validators.

---

## Data Structure

### **Normalized Data**

- **`_normalizedData`**:
  - Stores normalized stake values for validators in a period.
  - Includes:
    - `normalizedStake`: A mapping of validator IDs to their normalized stake values.
    - `normalizedSum`: The total normalized stake across validators.

### **Tracking Records**

- **`_tracker`**:
  - Maps each epoch to validator performance.
  - Records:
    - `qcVoteCount`: Number of finality votes cast by the validator.
    - `score`: Cumulative score of the validator in the epoch.

---

## Implications of Normalization

1. **Fair Competition**:
   - Caps excessive stakes to prevent validators with high stakes from dominating the network.
   - Ensures smaller validators can compete fairly in scoring.

2. **Dynamic Adjustments**:
   - Normalized values are recalculated for every new period.
   - Reflects changes in staking data and validator activity.

3. **Efficient Scoring**:
   - The iterative pivot-based normalization ensures an efficient and balanced scoring system.

---

## Summary

The `FastFinalityTracking` contract ensures fairness and incentivizes validator participation by combining a robust normalization technique with dynamic score calculations. By capping excessive stakes and rewarding active participation, it strengthens the Ronin network's security and efficiency.
