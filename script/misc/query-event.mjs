import { ethers } from "ethers";
import fs from "fs";
import dotenv from "dotenv";

dotenv.config();

const provider = new ethers.JsonRpcProvider(process.env.RONIN_TESTNET_SHADOW);
console.log("Connected to", provider);

const implArtifact = JSON.parse(fs.readFileSync("./deployments/ronin-testnet-shadow/RoninValidatorSetLogic.json"));
const proxyArtifact = JSON.parse(fs.readFileSync("./deployments/ronin-testnet-shadow/RoninValidatorSetProxy.json"));
const abi = implArtifact.abi;
const deployedBlock = Number(implArtifact.block_number);
console.log("Deployed block:", deployedBlock);
console.log("Proxy address:", proxyArtifact.address);

const validatorSet = new ethers.Contract(proxyArtifact.address, abi, provider);
console.log({ validatorSet });
const eventsToFilter = [
	"EmptyValidatorSet",
	"FastFinalityRewardDelegatorsDistributionFailed",
	"MiningRewardDelegatorsDistributionFailed",
	"MiningRewardDistributionFailed",
	"FastFinalityRewardDistributionFailed",
	"L2MiningRewardDistributionFailed",
];
async function filterEvents() {
	const chunkSize = 10000; // Number of blocks to query at a time
	const latestBlock = await provider.getBlockNumber();
	console.log("Latest block:", latestBlock);
	console.log("Expected steps to complete:", Math.ceil((latestBlock - deployedBlock) / chunkSize));

	// Create a filter for all events by combining topics
	const filters = eventsToFilter.map((event) => validatorSet.getEvent(event).fragment);

	// Flatten the topics array so each log matches any of the events in eventsToFilter
	const topics = [filters.map((filter) => filter.topicHash)]; // Only use the first topic for each event

	// Iterate over the block range in chunks
	for (let fromBlock = deployedBlock; fromBlock <= latestBlock; fromBlock += chunkSize) {
		const toBlock = Math.min(fromBlock + chunkSize - 1, latestBlock);

		// Fetch logs for all events in the current chunk
		console.log(`Fetching logs from block ${fromBlock} to ${toBlock} for all specified events`);
		const logs = await provider.getLogs({
			fromBlock: fromBlock,
			toBlock: toBlock,
			address: validatorSet.target,
			topics: topics,
		});

		console.log("Logs count:", logs.length);

		// Process each log to determine which event it matches
		logs.forEach((log) => {
			try {
				const parsedLog = validatorSet.interface.parseLog(log);
				if (parsedLog) {
					console.log(`Event ${parsedLog.name} detected:`, parsedLog.args);
				}
			} catch (error) {
				console.warn("Log parsing error:", error);
			}
		});
	}
}

filterEvents().catch(console.error);
