const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SignatureVerifier", function () {
  let verifier;
  let signer;
  let signerAddress;

  before(async function () {
    [signer] = await ethers.getSigners();
    signerAddress = await signer.getAddress();
    const SignatureVerifier = await ethers.getContractFactory(
      "SignatureVerifier"
    );
    verifier = await SignatureVerifier.deploy();
  });

  it("should verify the signer correctly", async function () {
    const message = "Hello, blockchain!";
    const messageHash = ethers.keccak256(ethers.toUtf8Bytes(message));

    const signature = await signer.signMessage(ethers.getBytes(messageHash));

    const recoveredAddress = await verifier.getSigner(messageHash, signature);
    expect(recoveredAddress).to.equal(signerAddress);
  });
});
