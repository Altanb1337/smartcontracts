const hre = require("hardhat");

async function main() {
    const OnePoolTokenContract = await hre.ethers.getContractFactory("OnePoolToken");
    const lotteryPoolContract = await ethers.getContractFactory("LotteryPoolTest");
    const poolMasterContract = await ethers.getContractFactory("PoolMaster");
    const bogAddress = "0xd7b729ef857aa773f47d37088a1181bb3fbf0099";
    const devAddress = "0xCCb073371c84c5Ef0d0E1F699aB58084D9514cC9";
    const pancakeSwapRouter = "0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F"

    // Deploy OnePoolToken
    const onePoolToken = await OnePoolTokenContract.deploy();
    await onePoolToken.deployed();
    console.log("OnePoolToken deployed to:", onePoolToken.address);

    // Verify OnePoolToken
    await hre.run("verify:verify", {
        address: onePoolToken.address
    });

    // Deploy LotteryPool
    const lotteryPool = await lotteryPoolContract.deploy(onePoolToken.address, bogAddress);
    await lotteryPool.deployed();
    console.log("LotteryPool deployed to:", lotteryPool.address);

    // Verify LotteryPool
    await hre.run("verify:verify", {
        address: lotteryPool.address,
        constructorArguments: [
            onePoolToken.address,
            bogAddress
        ],
    });

    // Deploy PoolMaster
    let onePoolPerBlock = ethers.utils.parseEther('0.25');
    const poolMaster = await poolMasterContract.deploy(onePoolToken.address, devAddress, 1, 1, onePoolPerBlock, lotteryPool.address);
    await poolMaster.deployed();
    console.log("PoolMaster deployed to:", poolMaster.address);

    // Verify PoolMaster
    await hre.run("verify:verify", {
        address: poolMaster.address,
        constructorArguments: [
            onePoolToken.address,
            devAddress,
            1, 1, onePoolPerBlock,
            lotteryPool.address
        ],
    });

    // Set BoggedToken address of OnePoolToken
    await onePoolToken.updateBoggedTokenAddress(bogAddress);
    console.log("BoggedToken address of OnePoolToken setted");

    // Set LotteryPool address of OnePoolToken
    await onePoolToken.updateLotteryPoolAddress(lotteryPool.address);
    console.log("LotteryPool address of OnePoolToken setted");

    // Set PancakeSwapRouter of OnePoolToken and create 1POOL/BNB pair
    await onePoolToken.setPancakeSwapRouter(pancakeSwapRouter);
    console.log("PancakeSwapRouter address of OnePoolToken setted")

    // TODO CreatePair

    // TODO Approve Router for Bog and 1POOL

    // TODO (if needed) AddLiquidityETH for BOG and 1POOL

    // TODO TransferOwnership to PoolMaster
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
