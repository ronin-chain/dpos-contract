# RoninRandomBeacon Contract Documentation

The `RoninRandomBeacon` contract is responsible for generating secure random beacons, managing validator thresholds, and ensuring fair validator selection.

---

## Overview

### **1. Random Beacon Management**

- Handles the lifecycle of random beacon requests, including:
  - Requesting a random seed for the next period.
  - Validating and finalizing the random seed with cryptographic proofs.
  - Storing the finalized beacon value for validator selection.

### **2. Validator Threshold Management**

- Maintains and updates thresholds for different validator types:
  - Governing Validators.
  - Standard Validators.
  - Rotating Validators.

---

## Validator Selection: Filtering Valid Candidates

The `RoninRandomBeacon` contract ensures that only eligible candidates are included in the validator set. The filtering process applies the following criteria:

1. **Exclude Newly Registered Candidates**:
   - Candidates within the cooldown period are excluded from selection.
   - Ensures fairness by preventing immediate participation of new candidates.

2. **Enforce Thresholds**:
   - Valid candidates are filtered based on thresholds defined for each validator type:
     - Governing Validators (GV)
     - Standard Validators (SV)
     - Rotating Validators (RV)

3. **Sort by Weights and Staking Amounts and Random Seed**:
   - Governing Validators (GV) are given priority based on their trusted weights.
   - Standard Validators (SV) are sorted based on their staking amounts.
   - Rotating Validators (RV) are selected based on a random seed.

---

### **4. Unavailability Management**

- Tracks validator unavailability and enforces slashing penalties when thresholds are exceeded.

---

## Flow

### **1. Random Seed Request**

- At the beginning of a new period, the `RoninValidatorSet` contract requests a random seed.
- Validators submit cryptographic proofs to fulfill the request.

### **2. Random Beacon Finalization**

- At the end of the period:
  - The random beacon is finalized using the submitted proofs.
  - Pending validator IDs are finalized for the next period.

### **3. Validator Selection**

- Finalized random beacon values are used to select validators for the current period and epoch.
- Selected validators are used for promoting to block producer.

### **4. Unavailability Tracking and Slashing**

- Validator activity is monitored throughout the period.
- Validators failing to meet availability thresholds are penalized via slashing.

### **5. Transition to New Period**

- At the end of the each epoch, the contract transitions to a new period with updated validator sets and configurations.
