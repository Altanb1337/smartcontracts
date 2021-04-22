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
}