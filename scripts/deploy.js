// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const friendTechAmount = hre.ethers.parseEther("0.05");

  const sightseaV2 = await hre.ethers.deployContract("SightseaV2", {
    value: friendTechAmount,
  });

  await sightseaV2.waitForDeployment();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
