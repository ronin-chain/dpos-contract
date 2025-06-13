import "@typechain/hardhat";
import "@nomiclabs/hardhat-ethers";
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-chai-matchers";

import { HardhatUserConfig, NetworkUserConfig, SolcUserConfig } from "hardhat/types";

const DEFAULT_MNEMONIC = "title spike pink garlic hamster sorry few damage silver mushroom clever window";

const local: NetworkUserConfig = {
	url: "http://localhost:8545",
	accounts: { mnemonic: DEFAULT_MNEMONIC },
};

const compilerConfig: SolcUserConfig = {
	version: "0.8.27",
	settings: {
		optimizer: {
			enabled: true,
			runs: 1000,
		},
	},
};

const config: HardhatUserConfig = {
	solidity: {
		compilers: [compilerConfig],
	},
	typechain: {
		outDir: "tools/types",
	},
	paths: {
    sources: "./src",
		tests: "test/hardhat",
	},
	networks: {
		hardhat: {
			hardfork: "istanbul",
			accounts: {
				mnemonic: DEFAULT_MNEMONIC,
				count: 150,
				accountsBalance: "1000000000000000000000000000", // 1B RON
			},
			allowUnlimitedContractSize: true,
		},
		local,
	},
	mocha: {
		timeout: 100000, // 100s
	},
};

export default config;
