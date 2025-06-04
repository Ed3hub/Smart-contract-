const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");
const { keccak256, toUtf8Bytes } = require("ethers");

module.exports = buildModule("CertificatesModule", (m) => {
  const certificates = m.contract("Ed3hubCertificate");
  
  
  const MINTER_ROLE = keccak256(toUtf8Bytes("MINTER_ROLE"));

  const admin = m.getAccount(0);
  m.call(certificates, "grantRole", [MINTER_ROLE, admin], { gasLimit: 1000000 });

  return { certificates };
});