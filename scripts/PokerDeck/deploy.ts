import { ethers } from "hardhat";

async function main() {
  /**
   * Deploy helper library first
   */
  const Helper = await ethers.getContractFactory("Helper");
  const helperContract = await Helper.deploy();
  await helperContract.deployed();

  /**
   * Deploy poker deck contract with linked Helper library
   */
  const PokerDeck = await ethers.getContractFactory("PokerHand", {
    libraries: {
      Helper: helperContract.address,
    },
  });

  const pokerDeck = await PokerDeck.deploy();
  await pokerDeck.deployed();

  console.log("Deployed PokerHand contract at:", pokerDeck.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
