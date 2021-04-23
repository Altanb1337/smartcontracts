const { expect } = require("chai");

describe("PoolMaster contract", function () {

    let onePoolToken;
    let token;
    let lotteryPoolContract;
    let lotteryPool;
    let poolMasterContract;
    let poolMaster;
    let owner;
    let dev;
    let addr1;
    let lptoken;
    let addrs;

    beforeEach(async function () {
        // Get the ContractFactory and Signers here.
        onePoolToken = await ethers.getContractFactory("OnePoolToken");
        lotteryPoolContract = await ethers.getContractFactory("LotteryPool");
        poolMasterContract = await ethers.getContractFactory("PoolMaster");
        [owner, dev, addr1, lptoken, ...addrs] = await ethers.getSigners();

        // To deploy our contract, we just have to call onePoolToken.deploy() and await
        // for it to be deployed(), which happens onces its transaction has been
        // mined.
        token = await onePoolToken.deploy();
        lotteryPool = await lotteryPoolContract.deploy(token.address, addr1.address, token.address);
        poolMaster = await poolMasterContract.deploy(token.address, dev.address, 1, 1, 10, lotteryPool.address);
    });

    describe("Deployment", function () {
        it("Should set the right owner", async function () {
            // This test expects the owner variable stored in the contract to be equal
            // to our Signer's owner.
            expect(await poolMaster.owner()).to.equal(owner.address);
        });

        it("Should set proper attributes", async function () {
            const onePoolPerBlock = await poolMaster.onePoolPerBlock();
            expect(onePoolPerBlock).to.equal(1);

            const bonusEndBlock = await poolMaster.bonusEndBlock();
            expect(bonusEndBlock).to.equal(10);
        });

    });

    describe("Add function", function () {
        it("Shouldn't allow more than one pool", async function () {
            await poolMaster.add(lptoken.address);

            await expect(
                poolMaster.add(lptoken.address)
            ).to.be.revertedWith("We can only add one pool, the BNB/1POOL");

            // Only one pool
            const poolLength = await poolMaster.poolLength();
            expect(poolLength).to.equal(1);
        });
    });

    describe("updateOnePoolPerBlock function", function () {
        it("Should change onePoolPerBlock", async function () {
            var amount = ethers.utils.parseEther('1');
            await poolMaster.updateOnePoolPerBlock(amount);

            const onePoolPerBlock = await poolMaster.onePoolPerBlock();
            expect(onePoolPerBlock).to.equal(amount);
        });

        it("Shouldn't allow onePoolPerBlock outside 0.01-1 range", async function () {
            var amount = ethers.utils.parseEther('0.009');
            await expect(
                poolMaster.updateOnePoolPerBlock(amount)
            ).to.be.revertedWith("Invalid _onePoolPerBlock, not between 0.01 and 1");

            amount = ethers.utils.parseEther('0');
            await expect(
                poolMaster.updateOnePoolPerBlock(amount)
            ).to.be.revertedWith("Invalid _onePoolPerBlock, not between 0.01 and 1");

            amount = ethers.utils.parseEther('1.1');
            await expect(
                poolMaster.updateOnePoolPerBlock(amount)
            ).to.be.revertedWith("Invalid _onePoolPerBlock, not between 0.01 and 1");

            // Nothing changed
            const onePoolPerBlock = await poolMaster.onePoolPerBlock();
            expect(onePoolPerBlock).to.equal(1);
        });
    });

    describe("updatePoolRewardDivisor function", function () {
        it("Should change poolRewardDivisor", async function () {
            var amount = 15;
            await poolMaster.updatePoolRewardDivisor(amount);

            const poolRewardDivisor = await poolMaster.poolRewardDivisor();
            expect(poolRewardDivisor).to.equal(amount);
        });

        it("Shouldn't allow poolRewardDivisor outside (10-20) range", async function () {
            var amount = 0;
            await expect(
                poolMaster.updatePoolRewardDivisor(amount)
            ).to.be.revertedWith("_poolRewardDivisor must be between 10 and 20");

            var amount = 9;
            await expect(
                poolMaster.updatePoolRewardDivisor(amount)
            ).to.be.revertedWith("_poolRewardDivisor must be between 10 and 20");

            var amount = 21;
            await expect(
                poolMaster.updatePoolRewardDivisor(amount)
            ).to.be.revertedWith("_poolRewardDivisor must be between 10 and 20");

            // Nothing changed
            const poolRewardDivisor = await poolMaster.poolRewardDivisor();
            expect(poolRewardDivisor).to.equal(10);
        });
    });
});