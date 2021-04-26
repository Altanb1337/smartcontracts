/*
 * onepool.finance
 * Yield Farming/Lottery
 *
 * https://t.me/onepoolfinance
 */
pragma solidity >=0.6.0<0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./OnePoolToken.sol";

/// @title Yield Farming contract for onepool.finance
/// @notice Basically a sushiswap masterchef fork, but some changes
/// to deal more easily with only one pool
/// @dev removing :
/// - set(...) allocpoint is 1 and don't need to change
/// - massUpdatePool(...)
contract PoolMaster is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of 1POOLs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accOnePoolPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accOnePoolPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. 1POOLs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that 1POOLs distribution occurs.
        uint256 accOnePoolPerShare; // Accumulated 1POOLs per share, times 1e12. See below.
    }

    // The One Pool Token.
    OnePoolToken public onepool;

    // Dev address.
    address public devAddr;

    // Lottery pool address.
    address public lotteryPoolAddr;

    // Block number when bonus 1POOL period ends.
    uint256 public bonusEndBlock;
    // 1POOL tokens created per block.
    uint256 public onePoolPerBlock;
    // Bonus muliplier for early 1POOL makers.
    uint256 public constant BONUS_MULTIPLIER = 2;

    // Info of each pool.
    PoolInfo[] public poolInfo;

    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;

    // Total allocation points. Must be the sum of all allocation points in all pools.
    // Because there is only 1 pool, totalAllocPoint will be 1. But we keep the mechanism
    // of allocation points to prevent from regression. MasterChef code is already fine.
    uint256 public totalAllocPoint = 0;

    // The block number when 1POOL mining starts.
    uint256 public startBlock;

    // Divisor who determines the percentage for the LotteryPool
    // Initially 50%
    uint256 public poolRewardDivisor = 2;

    // If the devfund is enabled
    bool public devFundEnabled = true;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        OnePoolToken _onepool,
        address _devAddr,
        uint256 _onePoolPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock,
        address _lotteryPoolAddr
    ) public {
        require(_devAddr != address(0), "Dev address validation");
        require(_lotteryPoolAddr != address(0), "Lottery address validation");
        onepool = _onepool;
        devAddr = _devAddr;
        onePoolPerBlock = _onePoolPerBlock;
        bonusEndBlock = _bonusEndBlock;
        startBlock = _startBlock;
        lotteryPoolAddr = _lotteryPoolAddr;
    }

    /// @return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        } else if (_from >= bonusEndBlock) {
            return _to.sub(_from);
        } else {
            return bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER).add(
                _to.sub(bonusEndBlock)
            );
        }
    }

    /// @notice Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 onePoolReward = multiplier.mul(onePoolPerBlock).mul(pool.allocPoint).div(totalAllocPoint);

        onepool.mint(lotteryPoolAddr, onePoolReward.div(poolRewardDivisor)); // 10% 1POOL to the LotteryPool (100/10 = 10)

        if (devFundEnabled) {
            onepool.mint(devAddr, onePoolReward.div(50));   // 2% 1POOL to the devs fund (100/50 = 2)
        }

        onepool.mint(address(this), onePoolReward);
        pool.accOnePoolPerShare = pool.accOnePoolPerShare.add(onePoolReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    /// @notice Add the liquidity pool. Can only be called by the owner.
    /// You can only add one liquidity pool
    /// @dev removing the massUpdatePool, won't be called if we can add only
    /// one pool. The pool allocation points is 1.
    function add(IERC20 _lpToken) external onlyOwner {
        require(poolInfo.length == 0, "We can only add one pool, the BNB/1POOL");
        uint256 allocPoint = 1;

        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(allocPoint);

        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: allocPoint,
            lastRewardBlock: lastRewardBlock,
            accOnePoolPerShare: 0
        }));
    }

    /// @notice Update the bonusEndBlock
    function updateBonusEndBlock(uint256 _bonusEndBlock) external onlyOwner {
        bonusEndBlock = _bonusEndBlock;
    }

    /// @notice update the poolRewardDivisor
    /// @param _poolRewardDivisor between 1 and 20.
    /// It means that the percentage for the liquidity pool is only between 10% and 100%
    /// This mechanism regulates the growth of the LotteryPool
    function updatePoolRewardDivisor(uint256 _poolRewardDivisor) external onlyOwner {
        require(_poolRewardDivisor <= 20 && _poolRewardDivisor >= 1, "_poolRewardDivisor must be between 1 and 20");
        poolRewardDivisor = _poolRewardDivisor;
    }

    /// @return the number of pools
    /// In the case of this project, must return 1
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    /// @notice Update the value of onePoolPerBlock
    /// Must be between O.5 and 1.5 1POOL per block
    function updateOnePoolPerBlock(uint256 _onePoolPerBlock) external onlyOwner {
        require(_onePoolPerBlock <= uint256(1).mul(1e18) && _onePoolPerBlock >= uint256(1).mul(1e16),
            "Invalid _onePoolPerBlock, not between 0.01 and 1");
        onePoolPerBlock = _onePoolPerBlock;
    }

    /// @notice View function to see pending 1POOLs on frontend.
    function pendingOnePool(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accOnePoolPerShare = pool.accOnePoolPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 onePoolReward = multiplier.mul(onePoolPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accOnePoolPerShare = accOnePoolPerShare.add(onePoolReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accOnePoolPerShare).div(1e12).sub(user.rewardDebt);
    }

    /// @notice Deposit LP tokens to PoolMaster for 1POOL allocation.
    function deposit(uint256 _pid, uint256 _amount) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);

        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accOnePoolPerShare).div(1e12).sub(user.rewardDebt);
            if (pending > 0) {
                safeOnePoolTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accOnePoolPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    /// @notice Withdraw LP tokens from PoolMaster.
    function withdraw(uint256 _pid, uint256 _amount) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);

        uint256 pending = user.amount.mul(pool.accOnePoolPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            safeOnePoolTransfer(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accOnePoolPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    /// @notice Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        // Preventing from reentrancy attack
        uint256 userAmount = user.amount;

        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), userAmount);
        emit EmergencyWithdraw(msg.sender, _pid, userAmount);
    }

    /// @notice Update dev address by the previous dev.
    function dev(address _devAddr) external {
        require(msg.sender == devAddr, "Not dev");
        require(_devAddr != address(0), "Dev address validation");
        devAddr = _devAddr;
    }

    /// @notice Disable the dev fund
    /// After calling this function, the dev fund can't be enabled anymore
    function disableDevFund() external {
        require(msg.sender == devAddr, "Not dev");
        devFundEnabled = false;
    }

    /// @notice update the liquidity lock divisor from OnePoolToken
    /// Since PoolMaster is the owner, we added this function.
    function updateLiquidityLockDivisor(uint256 liquidityLockDivisor) external onlyOwner {
        onepool.updateLiquidityLockDivisor(liquidityLockDivisor);
    }

    function useLockedTokens(
        uint256 pLockLiquidity,
        uint256 pRewardLp,
        uint256 pBurn,
        uint256 pLotteryGas,
        uint256 pRewardLottery
    ) external onlyOwner {
        onepool.useLockedTokens(pLockLiquidity, pRewardLp, pBurn, pLotteryGas, pRewardLottery);
    }

    /// @notice Safe 1POOL transfer function, just in case if rounding error
    /// causes pool to not have enough 1POOLs.
    function safeOnePoolTransfer(address _to, uint256 _amount) internal {
        uint256 onePoolBalance = onepool.balanceOf(address(this));
        if (_amount > onePoolBalance) {
            onepool.transfer(_to, onePoolBalance);
        } else {
            onepool.transfer(_to, _amount);
        }
    }
}