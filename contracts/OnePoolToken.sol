/*
 * onepool.finance
 * Yield Farming/Lottery
 *
 * https://t.me/onepoolfinance
 */
pragma solidity >=0.6.0<0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./erc20/GouvernanceAndLockedERC20.sol";
import "./interfaces/IPancakeFactory.sol";

contract OnePoolToken is GouvernanceAndLockedERC20, Ownable {

    using SafeMath for uint256;

    constructor() public {
        // Send initial supply to owner.
        // We only have one pool : BNB/1POOL, so the owner have to the initial
        // liquidity provider.
        _mint(msg.sender, uint256(10000).mul(1e18));

        // 25 = 4% locked for every transfer
        liquidityLockDivisor = 25;
    }

    /// @notice Allow everybody to burn 1POOL tokens
    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }

    /// @notice Creates `_amount` token to `_to`. Must only be called by the OnePoolMaster contract.
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }

    /// @notice update the liquidity lock divisor
    function updateLiquidityLockDivisor(uint256 _liquidityLockDivisor) external onlyOwner {
        liquidityLockDivisor = _liquidityLockDivisor;
    }

    /// @notice the BoggedFinance token address
    function updateBoggedTokenAddress(address bogTokenAddr) external onlyOwner {
        boggedToken = IERC20(bogTokenAddr);
    }

    /// @notice update LotteryPool address
    /// We need this address to send LotteryGas
    function updateLotteryPoolAddress(address _lotteryPoolAdr) external onlyOwner {
        lotteryPoolAdr = _lotteryPoolAdr;
    }

    /// @notice set PancakeSwapV2Router address and will create the 1POOL/BNB Pair
    /// Once setted, it can't be done again.
    function setPancakeSwapRouterAndCreatePair(address _pancakeV2Router) external onlyOwner {
        require(pancakeV2Router == address(0), "OnePoolToken::setPancakeSwapRouterAndCreatePair: pancakeV2Router already setted");
        pancakeV2Router = _pancakeV2Router;
        IPancakeRouter02 router = IPancakeRouter02(pancakeV2Router);
        pancakeV2Pair = IPancakeFactory(router.factory())
        .createPair(address(this), router.WETH());
    }
}