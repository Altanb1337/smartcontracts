pragma solidity >=0.6.0<0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BoggedToken is ERC20("BoggedToken", "BOG"), Ownable {
    using SafeMath for uint256;

    constructor() public {}

    /// @notice mint amount of BOG token to
    /// the msg.sender for testing purpose
    function mintToken(uint256 _amount) public {
        _mint(msg.sender, _amount);
    }
}
