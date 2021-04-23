/*
 * onepool.finance
 * Yield Farming/Lottery
 *
 * https://t.me/onepoolfinance
 */
pragma solidity >=0.6.0<0.8.0;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./OnePoolToken.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";

interface IReceivesBogRand {
    function receiveRandomness(uint256 random) external;
}

interface IBogRandOracle {
    function requestRandomness() external;
    function getNextHash() external view returns (bytes32);
    function getPendingRequest() external view returns (address);
    function removePendingRequest(address adr, bytes32 nextHash) external;
    function provideRandomness(uint256 random, bytes32 nextHash) external;
    function seed(bytes32 hash) external;
}

/// @title Lottery smart contract of onepool.finance
/// Using BogTools (BogRNG) to get random numbers
/// See : https://docs.bogtools.io/getting-random-numbers
contract LotteryPool is Ownable, IReceivesBogRand {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // The 1POOL token
    OnePoolToken public onepool;

    // Oracle
    IBogRandOracle public oracle;

    // Bogged Finance Token
    IERC20 public boggedToken;

    // Info of a player
    struct Player {
        address addr;           // Address of the winner
        uint256 timestamp;      // Block number timestamp
        uint256 amount;         // Amount of the 1POOL reward
        uint256 bet;            // Amount of 1POOL bet
    }

    // The last winner of the lottery
    Player public winner;

    // Simplified list of winners addresses
    mapping (address => bool) public winnersAddr;

    // Count the number of players (info for the frontend)
    Counters.Counter private totalPlayerCounter;

    // Duration of the pause after someone won
    uint public pauseDuration;

    // To give the pool time to fill up once someone won the lottery
    bool public paused;

    // If issues with the contract, can stop the lottery mechanism
    bool public stopped;

    // BOG fee amount for using the Oracle
    uint256 public bogFee;

    // When you play to the lottery, you are waiting for the BogRNG oracle (not on the same
    // transaction) to give a random number and trigger the lottery (run).
    // The current player is the one waiting for this event.
    Player public currentPlayer;

    // The lottery is currently playing (waiting for BogTools)
    bool public playing;

    event played(uint256 _reward, address _player, bool won);
    event unpaused();
    event skipped(address _player);
    event nowPlaying(uint256 _reward, address _player, uint256 bet);

    constructor(OnePoolToken _onepool, address _bogRandOracleAddr, address _bogTokenAddr) public {
        onepool = _onepool;
        paused = false;
        pauseDuration = 30 minutes;
        stopped = true;
        playing = false;
        bogFee = uint256(25).mul(1e16); // 0.25

        oracle = IBogRandOracle(_bogRandOracleAddr);
        boggedToken = IERC20(_bogTokenAddr);

        // Approve oracle to spend BOG from this contract so fees can be taken
        boggedToken.approve(address(oracle), uint256(-1));
    }

    /// @notice play to the lottery !
    /// Playing means that you are not the current player, and
    /// you are waiting for the oracle to give a random number and trigger
    /// the mechanism.
    function play(uint256 _bet) public {
        unPause(); // Try to unpause the lottery if possible
        require(msg.sender != currentPlayer.addr, "LotteryPool::play: Cant play twice in a succession");
        require(allowedToPlay(_bet, msg.sender), "LotteryPool::play: You're not allowed to play");
        require(onepool.balanceOf(address(msg.sender)) >= _bet, "LotteryPool::play: You can't bet more than what you have");

        if (neededBogAmount() > 0) {
            // Send 0.25 BOG to the lottery pool (to pay the fees)
            boggedToken.transferFrom(msg.sender, address(this), bogFee);
        }

        // Burn the bet whatever the result
        // We send the amount to the pool then the pool burn the amount
        onepool.transferFrom(address(msg.sender), address(this), _bet);
        onepool.burn(_bet);

        // msg.sender is now the currentPlayer
        currentPlayer = Player({
            addr : msg.sender,
            timestamp : block.timestamp,
            amount : nextReward(),
            bet : _bet
        });
        Counters.increment(totalPlayerCounter);

        playing = true;

        IBogRandOracle(oracle).requestRandomness();

        emit nowPlaying(currentPlayer.amount, currentPlayer.addr, currentPlayer.bet);
    }

    /// @notice Check if the lottery need to be unpause
    /// @return true if it must be unpaused with the function "unPause()"
    /// If not, return false
    function unpausable() public view returns (bool) {
        if (winner.bet == 0) {
            return true;
        } else {
            return (winner.timestamp + pauseDuration) <= block.timestamp;
        }
    }

    /// @notice Check if a given player (address) is allowed to play
    /// @param bet the amount the player wants to bet
    /// @param player the address of the player
    /// @return true if the following conditions are strictly satisfied :
    /// -> The bet is half inferior than the lottery pool
    /// -> The lottery pool is not equal to 0
    /// -> The bet is not equal to 0
    /// -> The lottery is not paused
    /// -> The player never won
    /// -> The player is not a smart contract
    /// -> The lottery is not stopped
    /// -> The lottery is not "playing" (waiting for bogtools random number)
    /// -> The player has 0.25 BOG in his wallet
    ///
    /// WARNING :
    /// The check (isContract) that the player is not a smart contract can by bypassed (unsafe).
    /// It prevent partially, it can be called from a contract in construction (isContract return false
    /// and can be allowed to play).
    ///
    function allowedToPlay(uint256 bet, address player) public view returns (bool) {
        return !stopped && !won(player) && unpausable() && rightBetAmount(bet)
                && !Address.isContract(player) && !playing
                && isRightBogBalance(player)
                && bet > 0;
    }

    /// @notice Try to unpause the lottery if the lottery is unpausable.
    function unPause() public {
        require(unpausable(), "LotteryPool::unPause: Need to be unpausable");
        if (paused = true) {
            // Emit unpaused only if paused change from true to false
            emit unpaused();
        }
        paused = false;
    }

    /// @return true if the given player already won the lottery
    function won(address _player) public view returns (bool) {
        return winnersAddr[_player];
    }

    /// @return the amount you can win if you play at this
    /// current block
    function nextReward() public view returns (uint256) {
        return onepool.balanceOf(address(this));
    }

    /// @return the amount won by the last winner
    function lastReward() external view returns (uint256) {
        if (winner.bet == 0) {
            return 0;
        } else {
            return winner.amount;
        }
    }

    /// @notice update the pause duration
    /// Allows adjustment of the lottery if the initial 30 minutes pause
    /// is not enough.
    function changePauseDuration(uint _duration) public onlyOwner {
        pauseDuration = _duration;
    }

    /// @return the lottery gas value
    /// Lottery Gas means the LotteryPool BOG balance
    function lotteryGas() public view returns (uint256){
        return boggedToken.balanceOf(address(this));
    }

    /// Randomness callback function
    /// @notice Receive the random number from BogRNG and run the lottery
    /// for the player waiting
    /// @param random the random number given by BogRNG oracle
    function receiveRandomness(uint256 random) external override {
        // Ensure the sender is the oracle
        require(msg.sender == address(oracle), "LotteryPool::receiveRandomness: need to be the oracle");
        run(random);
    }

    /// @return the total number of players
    function totalPlayerNumber() external view returns (uint256){
        return Counters.current(totalPlayerCounter);
    }

    /// @notice Update "stopped", to stop of unstop the lottery.
    /// In case of critical vulnerabilities, the funds must be protected.
    /// @param _value true to stop, false to unstop
    function updateStopped(bool _value) external onlyOwner {
        stopped = _value;
    }

    /// @return timestamp when the lottery is supposed to be
    /// unpausable : last winner timestamp + pause duration
    function unpauseTimestamp() external view returns (uint256) {
        if (winner.bet == 0) {
            return 0;
        } else {
            return (winner.timestamp + pauseDuration);
        }
    }

    /// @notice give the needed amount of bog to play the Lottery.
    /// If there is enough Lottery Gas, the player doesn't need any BOG (returns 0)
    /// If not, he needs 0,25 BOG
    function neededBogAmount() private view returns (uint256) {
        return (lotteryGas() >= bogFee) ? 0 : bogFee;
    }

    /// @return true if the bog balance of the given address is enough
    /// ( > 0.25 if no lottery gas)
    function isRightBogBalance(address _address) private view returns (bool) {
        return boggedToken.balanceOf(_address) >= neededBogAmount();
    }

    /// @return true if the bet is half inferior than the lottery pool
    /// If the pool equal 0, then return false
    function rightBetAmount(uint256 _bet) private view returns (bool) {
        if (nextReward() == 0) {
            return false;
        }
        return _bet <= nextReward().div(2);
    }

    /// @notice Play the lottery for the current player
    /// @param _externalRandomNumber the randomNumber provide by BogTools oracle
    ///
    /// Note :
    /// When the player wins, he wins the reward amount at the moment he played.
    /// It means that the pool can grow while waiting for the oracle callback.
    function run(uint256 _externalRandomNumber) private returns (bool) {
        require(playing, "LotteryPool::run: Need to be playing");
        bool result = false;

        bytes32 _blockhash = blockhash(block.number - 1);

        // adding some complexity
        bytes32 _structHash = keccak256(
            abi.encode(
                _blockhash,
                block.timestamp,
                block.difficulty,
                _externalRandomNumber
            )
        );

        /*
         * To define if the player won, we create a random number from the keccak256 hash
         * between 0 and the possible reward (using a modulo).
         * Then, to win the random number needs to be inferior or equal to the player bet.
         */
        uint256 mod = currentPlayer.amount + 1;
        uint256 randomNumber = uint256(_structHash)%mod;

        if (randomNumber <= currentPlayer.bet) {
            result = true;
        }

        if (result) {
            // You win !
            onepool.transfer(currentPlayer.addr, currentPlayer.amount);
            winnersAddr[currentPlayer.addr] = true;
            winner.addr = currentPlayer.addr;
            winner.timestamp = block.timestamp;
            winner.amount = currentPlayer.amount;
            winner.bet = currentPlayer.bet;
            paused = true;
        }
        playing = false;
        emit played(currentPlayer.amount, currentPlayer.addr, result);
        return result;
    }
}
