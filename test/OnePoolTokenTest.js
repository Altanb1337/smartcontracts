const { expect } = require("chai");

describe("Token contract", function () {

    let onePoolToken;
    let token;
    let owner;
    let addr1;
    let addr2;
    let addrs;

    beforeEach(async function () {
        // Get the ContractFactory and Signers here.
        onePoolToken = await ethers.getContractFactory("OnePoolToken");
        [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

        // To deploy our contract, we just have to call onePoolToken.deploy() and await
        // for it to be deployed(), which happens onces its transaction has been
        // mined.
        token = await onePoolToken.deploy();
    });

    describe("Deployment", function () {
        it("Should set the right owner", async function () {

            // This test expects the owner variable stored in the contract to be equal
            // to our Signer's owner.
            expect(await token.owner()).to.equal(owner.address);
        });

        it("Should set the 1POOL symbol", async function () {
            expect(await token.symbol()).to.equal("1POOL");
        });

        it("Should assign the total supply of tokens to the owner", async function () {
            const ownerBalance = await token.balanceOf(owner.address);
            expect(await token.totalSupply()).to.equal(ownerBalance);
        });
    });

    describe("Transactions", function () {
        it("Should transfer tokens between accounts", async function () {
            // Transfer 50 tokens from owner to addr1
            await token.transfer(addr1.address, 1000);
            const addr1Balance = await token.balanceOf(addr1.address);
            expect(addr1Balance).to.equal(960);

            // Transfer 50 tokens from addr1 to addr2
            // We use .connect(signer) to send a transaction from another account
            await token.connect(addr1).transfer(addr2.address, 960);
            const addr2Balance = await token.balanceOf(addr2.address);
            expect(addr2Balance).to.equal(922);
        });

        it("Should fail if sender doesn’t have enough tokens", async function () {
            const initialOwnerBalance = await token.balanceOf(owner.address);

            // Try to send 1 token from addr1 (0 tokens) to owner (1000 tokens).
            // `require` will evaluate false and revert the transaction.
            await expect(
                token.connect(addr1).transfer(owner.address, 1)
            ).to.be.revertedWith("transfer amount exceeds balance");

            // Owner balance shouldn't have changed.
            expect(await token.balanceOf(owner.address)).to.equal(
                initialOwnerBalance
            );
        });

        it("Should update balances after transfers", async function () {
            // Transfer 100 tokens from owner to addr1.
            await token.transfer(addr1.address, 100);

            // Transfer another 50 tokens from owner to addr2.
            await token.transfer(addr2.address, 200);

            // Check balances.
            const finalOwnerBalance = await token.balanceOf(owner.address);
            expect(finalOwnerBalance.toString()).to.equal('9999999999999999999700');

            const addr1Balance = await token.balanceOf(addr1.address);
            expect(addr1Balance).to.equal(96);

            const addr2Balance = await token.balanceOf(addr2.address);
            expect(addr2Balance).to.equal(192);
        });
    });
});