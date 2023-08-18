import * as path from "path";
import { expect, assert } from "chai";
import { ethers } from "hardhat";
import { Groth16Verifier } from "../build/typechain";

const crypto = require("crypto");
const { groth16 } = require("snarkjs");
const circomlib = require("circomlibjs");
const tester = require("circom_tester").wasm;

function hashString(input: string) {
  const hash = crypto.createHash("sha256");
  hash.update(input);
  return hash.digest("hex");
}

function hashToInt(input: string): BigInt {
  let sum = 0;
  for (let i = 0; i < input.length; i++) {
    sum += input.charCodeAt(i);
  }
  return BigInt(sum);
}

// ffjavascript has no types so leave circuit with untyped
type CircuitT = any;

const circuitPath = path.join(__dirname, "..", "circuits", "NFTMint.circom");

describe("Circuit Test", function () {
  let circuit: CircuitT;

  before(async function () {
    circuit = await tester(circuitPath);
  });

  it("NFTMint check withness", async () => {
    await circuit.loadConstraints();

    let poseidon = await circomlib.buildPoseidon();

    const secret = hashToInt(await hashString("My Secret Code"));
    const hash = poseidon([secret]);
    const address = BigInt("0x1111111111111111111111111111111111111111");

    const input = {
      hash: poseidon.F.toObject(hash),
      address: address,
      preimage: secret,
    };

    const witness = await circuit.calculateWitness(input, true);
    await circuit.checkConstraints(witness);
  });
});

describe("Verifier", function () {
  let Verifier;
  let verifier: Groth16Verifier;

  beforeEach(async function () {
    Verifier = await ethers.getContractFactory("Groth16Verifier");
    verifier = await Verifier.deploy();
  });

  it("Should return true for correct proofs", async function () {
    let poseidon = await circomlib.buildPoseidon();

    const secret = hashToInt(await hashString("My Secret Code"));
    const hash = poseidon([secret]);
    const address = BigInt("0x1111111111111111111111111111111111111111");

    const input = {
      hash: poseidon.F.toObject(hash),
      address: address,
      preimage: secret,
    };

    const { proof, publicSignals } = await groth16.fullProve(
      input,
      "build/NFTMint_js/NFTMint.wasm",
      "setup/final.zkey"
    );

    const calldata = await groth16.exportSolidityCallData(proof, publicSignals);

    const argv = calldata
      .replace(/["[\]\s]/g, "")
      .split(",")
      .map((x: number) => BigInt(x).toString());

    const a = [argv[0], argv[1]];
    const b = [
      [argv[2], argv[3]],
      [argv[4], argv[5]],
    ];
    const c = [argv[6], argv[7]];
    const Input = argv.slice(8);

    expect(await verifier.verifyProof(a, b, c, Input)).to.be.true;
  });
});
