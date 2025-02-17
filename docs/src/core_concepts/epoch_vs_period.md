# Epoch vs Period

Understanding the distinction between **Epoch** and **Period** is critical for grasping the underlying mechanics of the system. Both terms are used to represent time intervals but serve different purposes and are calculated differently.

---

## 1. What is an Epoch?

An **epoch** is a fixed time unit measured in **blocks**. It represents the core timing mechanism for operations within the blockchain.

- **Definition**:
  - An epoch is defined as a set number of blocks.
- **Configuration**:
  - In this system, 1 epoch = **200 blocks**.
- **Approximate Duration**:
  - Each block takes approximately **3 seconds** to generate.
  - Thus, 1 epoch ≈ **10 minutes**.

**Example**:

- Blocks 0–199 belong to epoch 0.
- Blocks 200–399 belong to epoch 1.
- Blocks 400–599 belong to epoch 2, and so on.

Epochs are used for:

- Validator rotation.
- Slashing mechanisms.
- Reward distribution calculations.

---

## 2. What is a Period?

A **period** is a broader time unit measured in **timestamps**, typically aligned with **calendar days**. It serves as a higher-level grouping of epochs.

- **Definition**:
  - A period ideally starts at **00:00 UTC** each day.
- **Challenges in Blockchain**:
  - Blockchain works with block numbers, not timestamps, making it difficult to align perfectly with real-world time.
  - Instead, the system determines a new period when the timestamp of the current epoch exceeds the next day’s threshold.

**Key Notes**:

- A period starts between **00:00 UTC → 00:15 UTC**, depending on block generation timing.
- Period duration is variable and influenced by network performance.

---

## 3. Key Differences

| Feature              | **Epoch**                                                  | **Period**                                                                         |
| -------------------- | ---------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| **Measurement Unit** | Number of blocks                                           | Timestamps (real-world time)                                                       |
| **Duration**         | Fixed (200 blocks ≈ 10 minutes)                            | Variable (aligned with calendar)                                                   |
| **Purpose**          | Operational tasks (e.g., record stats, validator rotation) | High-level grouping of epochs (e.g., reward distribution, randomization, slashing) |
| **Start Condition**  | Based on block number                                      | Based on UTC timestamp                                                             |

---

## 4. Interplay Between Epochs and Periods

Periods are determined by epochs, and the transition is triggered as follows:

1. At the end of each epoch, the system checks the **timestamp** of the last block.
2. If the timestamp indicates a new calendar day, a new period begins.
3. Validator roles, random beacons, and other operations are changed at the period boundary.

**Key Implications**:

- A period may contain fewer epochs if the network is slow (fewer blocks are produced per day).
- Epoch-based calculations remain deterministic, while period-based calculations adapt to timestamp variability.

---

## 5. Practical Example

Consider the following scenario:

- Block production rate: ~1 block per 3 seconds.
- Daily period duration: 24 hours = 86,400 seconds.
- Expected epochs per period: $$\approx \(\frac{86,400}{(200 \times 3)} $$

---

## 6. Visual Representation

```plaintext
+--------+-----------------------------------------------+-------------------------------------------------------------+
| Period |                       1                       |                              2                              |
+========+=======+=========+=========+=====+=============+=============+=============+=============+=====+=============+
|  Epoch |   0   |    1    |    2    | ... |     239     |     240     |     241     |     242     |     |             |
+--------+-------+---------+---------+-----+-------------+-------------+-------------+-------------+-----+-------------+
|  Block | 0-199 | 200-399 | 400-599 | ... | 47800-47999 | 48000–48199 | 48200–48399 | 48400–48599 | ... | 95800–95999 |
+--------+-------+---------+---------+-----+-------------+-------------+-------------+-------------+-----+-------------+
```

In this table:

- Each **period** consists of multiple **epochs**.
- Each **epoch** is defined by a range of block numbers.
- A **new period** starts when the UTC timestamp exceeds **00:00 UTC**.
