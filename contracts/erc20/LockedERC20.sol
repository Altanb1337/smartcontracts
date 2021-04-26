pragma solidity >=0.6.0<0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IPancakePair.sol";
import "../interfaces/IPancakeRouter02.sol";


/// @title ERC-20 token with gouvernance and lock mechanism
contract LockedERC20 is ERC20 {

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) public {}

    using SafeMath for uint256;

    // Events
    event LockLiquidity(uint256 tokenAmount, uint256 bnbAmount);
    event BurnLiquidity(uint256 lpTokenAmount);
    event BurnLockedToken(uint256 tokenAmount);
    event LotteryGasCreated(uint256 tokenAmount, uint256 bogAmount);
    event RewardLiquidityProviders(uint256 tokenAmount);
    event lockedSupplyUsed(uint256 amount);

    // PancakeSwap Router address
    address public pancakeV2Router;

    // PancakeSwap 1POOL/BNB pair address
    address public pancakeV2Pair;

    // Divisor who determines the locked percentage of every transfer
    uint256 public liquidityLockDivisor;

    // Bogged Finance Token
    IERC20 public boggedToken;

    // LotteryPool address
    address public lotteryPoolAdr;

    /// @notice override erc-20 transfer to lock a part of
    /// tha amount in the contract.
    function _transfer(address from, address to, uint256 amount) internal override {
        // calculate liquidity lock amount
        // dont transfer burn from this contract
        // or can never lock full lockable amount
        if (liquidityLockDivisor != 0 && from != address(this)) {
            uint256 liquidityLockAmount = amount.div(liquidityLockDivisor);
            super._transfer(from, address(this), liquidityLockAmount);
            super._transfer(from, to, amount.sub(liquidityLockAmount));
        }
        else {
            super._transfer(from, to, amount);
        }
    }

    // receive bnb from PancakeSwap
    receive() external payable {}

    /// @notice after adding liquidity with the locked tokens
    /// we can burn the LP Tokens received from PancakeSwap by calling
    /// this function.
    function burnLiquidity() external {
        uint256 balance = ERC20(pancakeV2Pair).balanceOf(address(this));
        require(balance != 0, "GouvernanceAndLockedERC20::burnLiquidity: burn amount cannot be 0");
        ERC20(pancakeV2Pair).transfer(address(0), balance);
        emit BurnLiquidity(balance);
    }

    /// @return the 1POOL balance of the contract
    /// These 1POOLs are locked, and ready to be :
    /// - Transformed in LotteryGas
    /// - Burned
    /// - Locked in PancakeSwap Liquidity Pool
    /// - Used to reward PancakeSwap LP
    function lockedSupply() external view returns (uint256) {
        return balanceOf(address(this));
    }

    /// @notice returns the 1POOL supply in the PancakeSwap Pool from
    /// burned LP token and burnable LP token.
    function supplyFromLockedLP() external view returns (uint256) {
        uint256 lpTotalSupply = ERC20(pancakeV2Pair).totalSupply();
        uint256 lpLocked = lockedLiquidity();

        // (lpLocked x 100) / lpTotalSupply = percentOfLpTotalSupply
        uint256 percentOfLpTotalSupply = lpLocked.mul(1e12).div(lpTotalSupply);

        return supplyOfPancakePair(percentOfLpTotalSupply);
    }

    /// @notice returns the 1POOL supply in the PancakeSwap Pool from burned LP.
    /// It means that the LP Token providing the following supply is "burned", it
    /// is locked forever.
    function supplyFromBurnedLP() external view returns (uint256) {
        uint256 lpTotalSupply = ERC20(pancakeV2Pair).totalSupply();
        uint256 lpBurned = burnedLiquidity();

        // (lpBurned x 100) / lpTotalSupply = percentOfLpTotalSupply
        uint256 percentOfLpTotalSupply = lpBurned.mul(1e12).div(lpTotalSupply);

        return supplyOfPancakePair(percentOfLpTotalSupply);
    }

    /// @notice returns the 1POOL supply in the PancakeSwap Pool from burnable LP.
    /// It means that the LP Token providing the following supply is "burnable", it
    /// can be locked forever (if burnLiquidity is called).
    function supplyFromBurnableLP() external view returns (uint256) {
        uint256 lpTotalSupply = ERC20(pancakeV2Pair).totalSupply();
        uint256 lpBurnable = burnableLiquidity();

        // (lpBurned x 100) / lpTotalSupply = percentOfLpTotalSupply
        uint256 percentOfLpTotalSupply = lpBurnable.mul(1e12).div(lpTotalSupply);

        return supplyOfPancakePair(percentOfLpTotalSupply);
    }

    /// @notice returns total LP amount (not token amount) :
    /// LP burned + LP burnable
    function lockedLiquidity() public view returns (uint256) {
        return burnableLiquidity().add(burnedLiquidity());
    }

    /// @notice returns LP amount (not token amount) ready
    /// to burn (after locking liquidity).
    function burnableLiquidity() public view returns (uint256) {
        return ERC20(pancakeV2Pair).balanceOf(address(this));
    }

    /// @notice returns burned LP amount (not token amount)
    /// We check the balanceOf of "0x" address (where the tokens are
    /// sent to be burnt).
    function burnedLiquidity() public view returns (uint256) {
        return ERC20(pancakeV2Pair).balanceOf(address(0));
    }

    /// @notice Swap half of the locked 1POOL for BNB, and add liquidity
    /// on pancakeswap
    function lockLiquidity(uint256 amount) internal {
        // lockable supply is the token balance of this contract
        require(amount <= balanceOf(address(this)), "GouvernanceAndLockedERC20::lockLiquidity: lock amount higher than lockable balance");
        require(amount != 0, "GouvernanceAndLockedERC20::lockLiquidity: lock amount cannot be 0");

        uint256 amountToSwapForBnb = amount.div(2);
        uint256 amountToAddLiquidity = amount.sub(amountToSwapForBnb);

        // needed in case contract already owns bnb
        uint256 bnbBalanceBeforeSwap = address(this).balance;
        swapTokensForBnb(amountToSwapForBnb);
        uint256 bnbReceived = address(this).balance.sub(bnbBalanceBeforeSwap);

        addLiquidity(amountToAddLiquidity, bnbReceived);
        emit LockLiquidity(amountToAddLiquidity, bnbReceived);
    }

    /// @notice reward liquidity providers by transfering
    /// 1POOL tokens to the PancakeSwap pair and perform a sync.
    /// @param amount the amount of LP tokens for rewarding
    function rewardLiquidityProviders(uint256 amount) internal {
        require(amount <= balanceOf(address(this)), "GouvernanceAndLockedERC20::rewardLiquidityProviders: amount higher than balance");
        require(amount != 0, "GouvernanceAndLockedERC20::rewardLiquidityProviders: amount cannot be 0");
        // avoid burn by calling super._transfer directly
        super._transfer(address(this), pancakeV2Pair, amount);
        IPancakePair(pancakeV2Pair).sync();
        emit RewardLiquidityProviders(amount);
    }

    /// @notice burn the locked tokens in the actual contract
    /// @param amount the amount to burn
    function burnLockedTokens(uint256 amount) internal {
        require(amount <= balanceOf(address(this)), "GouvernanceAndLockedERC20::burnLockedTokens: amount higher than balance");
        require(amount != 0, "GouvernanceAndLockedERC20::burnLockedTokens: burn amount cannot be 0");
        _burn(address(this), amount);
    }

    /// @notice create lottery gas with locked tokens (balance).
    /// Swap 1POOL for BOG and send the amount to the LotteryPool
    function createLotteryGas(uint256 amount) internal {
        require(amount <= balanceOf(address(this)), "GouvernanceAndLockedERC20::createLotteryGas: amount higher than balance");
        require(amount != 0, "GouvernanceAndLockedERC20::createLotteryGas: burn amount cannot be 0");

        swapOnePoolForBog(amount);
        uint256 bogReceived = boggedToken.balanceOf(address(this));
        require(bogReceived > 0, "GouvernanceAndLockedERC20::createLotteryGas: 0 BOG received from swap");

        boggedToken.transfer(lotteryPoolAdr, bogReceived);
    }

    /// @notice increase the lottery reward with locked tokens (balance).
    /// Send the tokens to the LotteryPool contract.
    function increaseLotteryReward(uint256 amount) internal {
        require(amount <= balanceOf(address(this)), "GouvernanceAndLockedERC20::createLotteryGas: amount higher than balance");
        require(amount != 0, "GouvernanceAndLockedERC20::createLotteryGas: burn amount cannot be 0");
        super._transfer(address(this), lotteryPoolAdr, amount);
    }

    /// @notice swap 1POOL for BNB
    /// Use the PancakeSwap router to swap
    function swapTokensForBnb(uint256 tokenAmount) private {
        address[] memory pancakePairPath = new address[](2);
        pancakePairPath[0] = address(this);
        pancakePairPath[1] = IPancakeRouter02(pancakeV2Router).WETH();

        _approve(address(this), pancakeV2Router, tokenAmount);

        IPancakeRouter02(pancakeV2Router)
        .swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            pancakePairPath,
            address(this),
            block.timestamp
        );
    }

    /// @notice Swap 1POOL for BOG
    /// Use the PancakeSwap router to swap
    function swapOnePoolForBog(uint256 tokenAmount) private {
        address[] memory pancakePairPath = new address[](3);
        pancakePairPath[0] = address(this);
        pancakePairPath[1] = IPancakeRouter02(pancakeV2Router).WETH();
        pancakePairPath[2] = address(boggedToken);

        _approve(address(this), pancakeV2Router, tokenAmount);

        IPancakeRouter02(pancakeV2Router)
        .swapExactTokensForTokens(
            tokenAmount,
            0,
            pancakePairPath,
            address(this),
            block.timestamp
        );
    }

    /// @notice Add liquidity for the 1POOL/BNB pool
    /// on PancakeSwap
    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        _approve(address(this), pancakeV2Router, tokenAmount);

        IPancakeRouter02(pancakeV2Router)
        .addLiquidityETH
        {value:bnbAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            address(this),
            block.timestamp
        );
    }

    /// @return the 1POOL supply in PancakeSwap Pair, with the given percentage applied.
    /// @param percent the percentage, where x means wei%
    function supplyOfPancakePair(uint256 percent) private view returns (uint256) {
        uint256 onePoolPancakeBalance = balanceOf(pancakeV2Pair);

        // (balance of 1POOL in PancakeSwap Pair x percent) / 100
        uint256 supply = onePoolPancakeBalance.mul(percent).div(1e12);
        return supply;
    }

    /// @return the 1POOL supply of the given balance
    /// with the given percentage applied.
    /// @param percent the percentage, where x means x%
    /// @param onePoolLockedBalance locked onepool
    function supplyOfLockedOnePool(uint256 percent, uint256 onePoolLockedBalance) internal pure returns (uint256) {
        // (balance of locked 1POOL x percent) / 100
        uint256 supply = onePoolLockedBalance.mul(percent).div(100);
        return supply;
    }
}