import { HardhatUserConfig } from "hardhat/config";

import "@nomicfoundation/hardhat-toolbox";
import "tsconfig-paths/register";

const config: HardhatUserConfig = {
  solidity: "0.8.16",
};

export default config;
