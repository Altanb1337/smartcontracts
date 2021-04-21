const { expect } = require("chai");

describe("LotteryPool contract", function () {

    let onePoolToken;
    let token;
    let boggedTokenContract;
    let boggedToken;
    let lotteryPoolContract;
    let lotteryPool;
    let poolMasterContract;
    let poolMaster;
    let owner;
    let dev;
    let addr1;
    let addr2;
    let lptoken;
    let addrs;

    beforeEach(async function () {
        // Get the ContractFactory and Signers here.
        onePoolToken = await ethers.getContractFactory("OnePoolToken");
        lotteryPoolContract = await ethers.getContractFactory("LotteryPoolTest");
        boggedTokenContract = await ethers.getContractFactory("BoggedToken");
        poolMasterContract = await ethers.getContractFactory("PoolMaster");
        [owner, dev, addr1, addr2, lptoken, ...addrs] = await ethers.getSigners();

        // To deploy our contract, we just have to call onePoolToken.deploy() and await
        // for it to be deployed(), which happens onces its transaction has been
        // mined.
        token = await onePoolToken.deploy();
        boggedToken = await boggedTokenContract.deploy();

        lotteryPool = await lotteryPoolContract.deploy(token.address, boggedToken.address);
        await lotteryPool.updateStopped(false);

        let onePoolPerBlock = ethers.utils.parseEther('1');
        poolMaster = await poolMasterContract.deploy(token.address, dev.address, 1, 1, onePoolPerBlock, lotteryPool.address);

        token.transferOwnership(poolMaster.address);

        // send manually token to the lottery pool
        let lotteryPoolFund = ethers.utils.parseEther('1000');
        await token.transfer(lotteryPool.address, lotteryPoolFund);

        await initSpending(owner);
        await initSpending(addr1);
    });

    describe("Deployment", function () {
        it("Should set the right owner", async function () {
            // This test expects the owner variable stored in the contract to be equal
            // to our Signer's owner.
            expect(await poolMaster.owner()).to.equal(owner.address);
        });

        it("Should set proper attributes", async function () {
            const paused = await lotteryPool.paused();
            expect(paused).to.equal(false);

            const stopped = await lotteryPool.stopped();
            expect(stopped).to.equal(false);

            const playing = await lotteryPool.playing();
            expect(playing).to.equal(false);
        });
    });

    describe("Play", function () {
        it("Shouldn't allow a bet more than half of the fund", async function () {
            let amount = ethers.utils.parseEther('600');
            await expect(
                lotteryPool.play(amount)
            ).to.be.revertedWith("You're not allowed to play");
        });

        it("Shouldn't allow to play twice", async function () {
            await lotteryPool.play(1);
            await lotteryPool.receiveRandomness(20);
            await expect(
                lotteryPool.play(1)
            ).to.be.revertedWith("Cant play twice in a succession");
        });

        it("Shouldn't allow to play more than what you have", async function () {
            // addr1 has 0 1POOL Token
            await expect(
                lotteryPool.connect(addr1).play(1)
            ).to.be.revertedWith("You can't bet more than what you have");
        });

        it("Shouldn't allow to bet 0 1POOL", async function () {
            await expect(
                lotteryPool.play(0)
            ).to.be.revertedWith("You're not allowed to play");
        });

        it("Should be playing", async function () {
            await lotteryPool.play(1);
            const playing = await lotteryPool.playing();
            expect(playing).to.equal(true);
        });

        it("Shouldn't allow to bet if already playing", async function () {
            await lotteryPool.play(1); // Owner playing

            // addr1 playing
            await token.transfer(addr1.address, 1); // owner transferring 1POOL to addr1

            await expect(
                lotteryPool.connect(addr1).play(1)
            ).to.be.revertedWith("You're not allowed to play");
        });

        it("Shouldn't allow to play if paused and can't be unpaused", async function () {
            await lotteryPool.play(1); // Owner playing
            await lotteryPool.receiveRandomness(0); // will win

            const playing = await lotteryPool.playing();
            expect(playing).to.equal(false);

            const paused = await lotteryPool.paused();
            expect(paused).to.equal(true);

            increaseTimestamp(1000) // around 15 minutes

            const unpausable = await lotteryPool.unpausable();
            expect(unpausable).to.equal(false);

            // send manually token to the lottery pool
            let lotteryPoolFund = ethers.utils.parseEther('1000');
            await token.transfer(lotteryPool.address, lotteryPoolFund);

            // addr1 playing
            await token.transfer(addr1.address, 100); // owner transferring 1POOL to addr1

            await expect(
                lotteryPool.connect(addr1).play(1)
            ).to.be.revertedWith("Need to be unpausable");
        });

        it("Should allow to play if paused but can be unpaused", async function () {
            await lotteryPool.play(1); // Owner playing
            await lotteryPool.receiveRandomness(0); // will win

            const playing = await lotteryPool.playing();
            expect(playing).to.equal(false);

            const paused = await lotteryPool.paused();
            expect(paused).to.equal(true);

            increaseTimestamp(2000) // around 30 minutes

            const unpausable = await lotteryPool.unpausable();
            expect(unpausable).to.equal(true);

            // send manually token to the lottery pool
            let lotteryPoolFund = ethers.utils.parseEther('1000');
            await token.transfer(lotteryPool.address, lotteryPoolFund);

            // addr1 playing
            await token.transfer(addr1.address, 100); // owner transferring 1POOL to addr1
            await expect(
                lotteryPool.connect(addr1).play(1)
            ).to.not.be.reverted;
        });

        it("Shouldn't allow to play if stopped", async function () {
            await lotteryPool.updateStopped(true);

            await expect(
                lotteryPool.play(1)
            ).to.be.revertedWith("You're not allowed to play");
        });

        it("Shouldn't allow to play if already won", async function () {
            await lotteryPool.play(1); // Owner playing

            await lotteryPool.receiveRandomness(0); // Will win

            const playing = await lotteryPool.playing();
            expect(playing).to.equal(false);

            const paused = await lotteryPool.paused();
            expect(paused).to.equal(true);

            increaseTimestamp(2000);

            const unpausable = await lotteryPool.unpausable();
            expect(unpausable).to.equal(true);

            // send manually token to the lottery pool
            let lotteryPoolFund = ethers.utils.parseEther('1000');
            await token.transfer(lotteryPool.address, lotteryPoolFund);

            // addr1 playing
            await token.transfer(addr1.address, 100); // owner transferring 1POOL to addr1
            await lotteryPool.connect(addr1).play(1);
            await lotteryPool.receiveRandomness(22);

            // Owner playing again
            await expect(
                lotteryPool.play(1)
            ).to.be.revertedWith("You're not allowed to play");
        });

        it("Shouldn't allow to play if not enough BOG", async function () {
            // Approving for addr2
            let amount = ethers.utils.parseEther('10000000');
            await boggedToken.connect(addr2).approve(lotteryPool.address, amount);
            await token.connect(addr2).approve(lotteryPool.address, amount);

            // addr2 playing
            await token.transfer(addr1.address, 100); // owner transferring 1POOL to addr2

            // addr2 has no BOG tokens, should be reverted
            await expect(
                lotteryPool.connect(addr2).play(1)
            ).to.be.revertedWith("You're not allowed to play");
        });

        it("Should change currentPlayer", async function () {
            await lotteryPool.play(1); // Owner playing
            await lotteryPool.receiveRandomness(1);

            let playing = await lotteryPool.playing();
            expect(playing).to.equal(false);

            let currentPlayer = await lotteryPool.currentPlayer();
            expect(currentPlayer.addr).to.equal(owner.address);

            // addr1 playing and should be the new player
            await token.transfer(addr1.address, 100); // owner transferring 1POOL to addr1
            await lotteryPool.connect(addr1).play(1);
            await lotteryPool.receiveRandomness(1);

            playing = await lotteryPool.playing();
            expect(playing).to.equal(false);

            currentPlayer = await lotteryPool.currentPlayer();
            expect(currentPlayer.addr).to.equal(addr1.address);
        });

        it("Should increment total player counter", async function () {
            let counter = await lotteryPool.totalPlayerNumber();
            expect(counter).to.equal(0);

            await lotteryPool.play(1); // Owner playing
            await lotteryPool.receiveRandomness(1);

            counter = await lotteryPool.totalPlayerNumber();
            expect(counter).to.equal(1);

            // addr1 playing and should be the new player
            await token.transfer(addr1.address, 100); // owner transferring 1POOL to addr1
            await lotteryPool.connect(addr1).play(1);
            await lotteryPool.receiveRandomness(1);

            currentPlayer = await lotteryPool.currentPlayer();
            expect(currentPlayer.addr).to.equal(addr1.address);

            counter = await lotteryPool.totalPlayerNumber();
            expect(counter).to.equal(2);
        });

        it("Should emit nowPlaying event", async function () {
            const reward = ethers.utils.parseEther('1000');
            const player = owner.address;
            const bet = 1;

            await expect(lotteryPool.play(1))
                .to.emit(lotteryPool, 'nowPlaying')
                .withArgs(reward, player, bet);
        });

        it("Should transfer the BOG token to the lottery", async function () {
            await lotteryPool.play(1); // Owner playing
            const bogBalance = await boggedToken.balanceOf(lotteryPool.address);
            const bet = ethers.utils.parseEther('0.25');

            expect(bogBalance.toString()).to.equal(bet.toString());
        });

        it("Should transfer and burn the bet", async function () {
            const lastPlayerOnePoolBalance = await token.balanceOf(owner.address);
            const lastReward = await lotteryPool.nextReward();
            const bet = 10;

            await lotteryPool.play(bet); // Owner playing

            const playerOnePoolBalance = await token.balanceOf(owner.address);
            const reward = await lotteryPool.nextReward();
            const expectedBalance = lastPlayerOnePoolBalance.sub(bet); // last balance - bet

            expect(playerOnePoolBalance.toString()).to.equal(expectedBalance.toString());
            expect(lastReward).to.equal(reward);
        });
    });

    describe("lastReward", function () {
        it("Should return the reward of the last winner", async function () {
            await lotteryPool.play(1); // Owner playing
            await lotteryPool.receiveRandomness(0); // Will win
        });
    });

    /**
     * Mint 1.000.000,00 BOG to receiver
     * Approve BOG and 1POOL for LotteryPool spending
     */
    async function initSpending(receiver) {
        let amount = ethers.utils.parseEther('10000000');
        await boggedToken.connect(receiver).mintToken(amount);
        await boggedToken.connect(receiver).approve(lotteryPool.address, amount);
        await token.connect(receiver).approve(lotteryPool.address, amount);
    }

    function increaseTimestamp(seconds) {
        ethers.provider.send("evm_increaseTime", [seconds]);
        ethers.provider.send("evm_mine");
    }
});