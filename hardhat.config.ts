/**
 * Import libraries
 */
import dotenv from "dotenv";
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "tsconfig-paths/register";

/**
 * Config dotenv first
 */
dotenv.config();

/**
 * Default hardhat configs
 */
const config: HardhatUserConfig = {
  solidity: "0.8.16",
};

/**
 * Import private key
 */
const privateKey = process.env.PRIVATE_KEY || "";
const testEnv = process.env.ENV === "test";

/**
 * If private key is available, attach network configs
 */
if (!testEnv && privateKey) {
  config.networks = {
    ganache: {
      url: "http://127.0.0.1:7545",
      chainId: 5777,
    },
    hardhat_local: {
      url: "http://127.0.0.1:8545",
      accounts: [privateKey],
      gasPrice: 250000000000,
    },
    hardhat: {
      forking: {
        url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_ID}`,
      },
      gas: "auto",
      gasPrice: "auto",
      chainId: 1,
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_ID}`,
      accounts: [privateKey],
      chainId: 4,
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_ID}`,
      accounts: [privateKey],
      gas: "auto",
      gasPrice: "auto",
      chainId: 1,
    },
    bsc_testnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      accounts: [privateKey],
      gas: "auto",
      gasPrice: "auto",
      chainId: 97,
    },
    bsc: {
      url: "https://bsc-dataseed1.binance.org",
      accounts: [privateKey],
      gas: "auto",
      gasPrice: "auto",
      chainId: 56,
    },
    hamsterbox: {
      url: "https://rpc.hamsterbox.xyz",
      accounts: [privateKey],
      gas: "auto",
      gasPrice: 0,
      chainId: 5722,
    },
  };
}

export default config;
