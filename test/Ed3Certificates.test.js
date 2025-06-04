const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const hre = require("hardhat");

describe("Ed3Certificates", function () {
  async function deployContractsFixture() {
    const [deployer, minter, student] = await hre.ethers.getSigners();

    const CertificatesFactory = await hre.ethers.getContractFactory("Ed3Certificates");
    const certificates = await CertificatesFactory.deploy();
    await certificates.waitForDeployment();

    const MINTER_ROLE = await certificates.MINTER_ROLE();
    await certificates.grantRole(MINTER_ROLE, minter.address);

    return { certificates, deployer, minter, student };
  }

  describe("Deployment", function () {
    it("should deploy the contract successfully", async function () {
      const { certificates } = await loadFixture(deployContractsFixture);
      expect(certificates.target).to.be.properAddress;
    });
  });

  describe("Role Management", function () {
    it("should grant MINTER_ROLE to the minter", async function () {
      const { certificates, minter } = await loadFixture(deployContractsFixture);
      expect(await certificates.hasRole(await certificates.MINTER_ROLE(), minter.address)).to.be.true;
    });

    it("should not allow non-minters to mint", async function () {
      const { certificates, student } = await loadFixture(deployContractsFixture);

      await expect(
        certificates.connect(student).mintCertificate(
          student.address,
          "COURSE101",
          "ipfs://some-metadata-uri"
        )
      ).to.be.revertedWithCustomError(certificates, "AccessControlUnauthorizedAccount");
    });
  });

  describe("Certificates", function () {
    it("should store correct metadata URI when minted", async function () {
      const { certificates, minter, student } = await loadFixture(deployContractsFixture);
      const courseCode = "WEB3-101";
      const tokenURI = "ipfs://QmTestCID";

      await certificates.connect(minter).mintCertificate(
        student.address,
        courseCode,
        tokenURI
      );

      expect(await certificates.tokenURI(1)).to.equal(tokenURI);
      expect(await certificates.ownerOf(1)).to.equal(student.address);
    });
  });
});
