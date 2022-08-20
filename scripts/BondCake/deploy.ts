import { ethers, upgrades } from "hardhat";

async function main() {
  /**
   * Deploy BondCake
   */
  const BondCake = await ethers.getContractFactory("BondCake");

  const bondCake = await upgrades.deployProxy(
    BondCake,
    [
      "0xFa60D973F7642B748046464e165A65B7323b0DEE", // Native Cake in BSC Testnet
      "0x683433ba14e8F26774D43D3E90DA6Dd7a22044Fe", // CakePool in BSC Testnet
    ],
    {
      unsafeAllowCustomTypes: true,
    }
  );

  await bondCake.deployed();
  console.log("Deployed BondCake contract at:", bondCake.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
