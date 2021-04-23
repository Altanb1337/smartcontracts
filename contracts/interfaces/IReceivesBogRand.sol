pragma solidity >=0.6.0<0.8.0;

interface IReceivesBogRand {
    function receiveRandomness(uint256 random) external;
}