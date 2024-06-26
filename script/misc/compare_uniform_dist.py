import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import random
from web3 import Web3
from eth_abi import encode


def calculate_weight(beacon: int, epoch: int, id: int, stake_amount: int) -> int:
    # Initialize web3
    w3 = Web3()

    # Define types for ABI encoding
    types = ["uint256", "uint256", "uint256"]

    values = [beacon, epoch, id]

    # ABI-encode the values
    encoded_data = encode(types, values)

    # Calculate the Keccak-256 hash
    h = w3.keccak(hexstr=encoded_data.hex())

    h_int = int.from_bytes(h, byteorder="big")

    # Split h into h1 (lower 128 bits) and h2 (upper remaining bits)
    h1 = h_int & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
    h2 = h_int >> 128

    # # Calculate the staked amount in terms of ether (assuming 1 ETH = 1e18)
    # s = int(stake_amount / 10**18)

    # # Calculate the weight as an integer result
    # weight = int((s**2) * (h1 ^ h2))

    # We don't involve stake_amount in the calculation
    return h1 ^ h2


# Parameters
num_samples = 10000
beacon_values = [
    random.SystemRandom().randrange(
        0,
        115792089237316195423570985008687907853269984665640564039457584007913129639935,  # 2^256
    )
    for _ in range(num_samples)
]
epoch_values = [
    random.SystemRandom().randrange(
        0,
        18446744073709551615,  # 2^64
    )
    for _ in range(num_samples)
]

id_values = [
    random.SystemRandom().randrange(
        0,
        1461501637330902918203684832716283019655932542975,  # 2^160
    )
    for _ in range(num_samples)
]


stake_amount = 10_000_000 * 10**18

# Calculate weights
weights = [
    calculate_weight(int(beacon), int(epoch), int(id), int(stake_amount))
    for beacon, epoch, id in zip(beacon_values, epoch_values, id_values)
]

# Plotting the value distribution
plt.figure(figsize=(12, 6))

# Seaborn histogram for calculate_weight distribution
sns.histplot(
    weights,
    kde=True,
    stat="density",
    bins=30,
    label="Calculate Beacon Hash Distribution",
)

# Uniform distribution for comparison
uniform_dist = np.random.uniform(min(weights), max(weights), num_samples)
sns.histplot(
    uniform_dist,
    kde=True,
    stat="density",
    bins=30,
    color="r",
    alpha=0.5,
    label="Uniform Distribution",
)

# Adding labels and legend
plt.title("Value Distribution of calculate_weight Function vs Uniform Distribution")
plt.xlabel("Weight Value")
plt.ylabel("Density")
plt.legend()
plt.show()
