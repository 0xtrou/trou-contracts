import {
  loadFixture,
  setBalance,
} from "@nomicfoundation/hardhat-network-helpers";

import { BigNumber, Contract } from "ethers";
import { ethers } from "hardhat";
import { before } from "mocha";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { atob } from "buffer";

/**
 * Define Fixture Data Interface
 */
type PokerHandFixtureData = {
  contract: Contract;
  owner: SignerWithAddress;
  invalidBuyer: SignerWithAddress;
  buyer: SignerWithAddress;
};

/**
 * Global test declaration
 */
describe("PokerHand", function () {
  const fixtures = async (): Promise<PokerHandFixtureData> => {
    /**
     * Get owner
     */
    const [owner, buyer, invalidBuyer] = await ethers.getSigners();
    await setBalance(buyer.address, ethers.utils.parseEther("100"));
    await setBalance(owner.address, ethers.utils.parseEther("100"));
    await setBalance(invalidBuyer.address, ethers.utils.parseEther("1"));

    /**
     * Deploy Helper Library
     */
    const helperLibraryFactory = await ethers.getContractFactory("Helper");
    const helperLibrary = await helperLibraryFactory.deploy();

    /**
     * Deploy PokerHand with linked library
     */
    const contractFactory = await ethers.getContractFactory("PokerHand", {
      libraries: {
        Helper: helperLibrary.address,
      },
    });
    const contract = await contractFactory.deploy();

    /**
     * Return fixture values
     */
    return {
      contract,
      owner,
      buyer,
      invalidBuyer,
    };
  };

  /**
   * Pre-setup Tests
   */
  describe("Pre-setup Tests", async function () {
    /**
     * Pre-setup test
     */
    it("Should fund ethers to accounts", async function () {
      /**
       * Load fixture data
       */
      const { buyer, owner } = await loadFixture(fixtures);

      /**
       * Expect
       */
      expect(await owner.getBalance()).to.below(ethers.utils.parseEther("100"));
      expect(await buyer.getBalance()).to.equal(ethers.utils.parseEther("100"));
    });
  });

  /**
   * Minting Test
   */
  describe("Minting Tests", async function () {
    let fixturesData: PokerHandFixtureData;
    let initialOwnerBalance: BigNumber;
    let initialBuyerBalance: BigNumber;

    before(async function () {
      fixturesData = await loadFixture(fixtures);
      initialOwnerBalance = await fixturesData.owner.getBalance();
      initialBuyerBalance = await fixturesData.buyer.getBalance();
    });

    it("Should fail if mint fee isn't provided", async function () {
      const { contract, invalidBuyer } = fixturesData;

      await expect(
        contract.connect(invalidBuyer).mint({ gasPrice: 0 })
      ).to.be.revertedWith("Error: below mint fee");
    });

    it("Should pass if minting with enough mint fee", async function () {
      const { contract, buyer } = fixturesData;

      await contract.connect(buyer).mint({
        value: ethers.utils.parseEther("50"),
        gasPrice: 0,
      });

      await contract.connect(buyer).mint({
        value: ethers.utils.parseEther("50"),
        gasPrice: 0,
      });

      expect(true);
    });

    it("Should credit owner whose address is tax pool 100 ether", async function () {
      const { owner } = fixturesData;

      const currentOwnerBalance = await owner.getBalance();

      expect(initialOwnerBalance.add(ethers.utils.parseEther("100"))).to.equal(
        currentOwnerBalance
      );
    });

    it("Should deduct buyer 100 ether", async function () {
      const { buyer } = fixturesData;

      const currentBuyerBalance = await buyer.getBalance();

      expect(initialBuyerBalance.sub(ethers.utils.parseEther("100"))).to.equal(
        currentBuyerBalance
      );
    });

    it("Should credit 1 PokerHand NFT to buyer", async function () {
      const { buyer, contract } = fixturesData;

      expect(await contract.connect(buyer).ownerOf("0")).to.equal(
        buyer.address
      );

      expect(await contract.connect(buyer).balanceOf(buyer.address)).to.equal(
        "2"
      );
    });

    it("Should receive valid metadata of NFT", async function () {
      /**
       * Get NFT metadata
       */
      const { buyer, contract } = fixturesData;
      const tokenUri = await contract.connect(buyer).tokenURI("0");

      /**
       * Expect the metadata is truthy
       */
      expect(!!tokenUri).to.be.true;

      /**
       * Extract base 64 data and convert to json
       */
      const base64Data = tokenUri
        .split(";")
        .reverse()[0]
        .split(",")
        .reverse()[0];
      const data = JSON.parse(atob(base64Data));

      /**
       * Assert data
       */
      expect(!!data.name).to.be.true;
      expect(!!data.description).to.be.true;
      expect(!!data.image).to.be.true;
      expect(data.attributes.length).to.eq(6);
    });
  });
});
