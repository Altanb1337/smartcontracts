*This repository contains the smart contracts and tests of onepool.finance project.
Any feedbacks or audits are welcome. Use it at your own risk. For more information, please email us at onepoolfinance@gmail.com.*

![](https://i.ibb.co/2c8Tf1P/1-resized.png=100x)

## Introduction

onepool.finance is a Yield Farming/Lottery protocol on Binance Smart Chain, using the 1POOL token.

The protocol is split in two ideas : 
- Yield Farming, with only **one** pool : 1POOL/BNB
- A lottery without drawing lots, where you can win instantly.

## Mechanism

However, these two ideas are all together. 
<br> The Yield Farming protocol (*PoolMaster*) mints 1POOL tokens to the Lottery protocol
(LotteryPool). The prize is bigger as more people are farming.

> **10% of the rewards value go to the LotteryPool (not a fee)**
> <br>`onepool.mint(lotteryPoolAddr, onePoolReward.div(poolRewardDivisor));`

All tokens in the pool are intended to be won. The user sets the  bet :
<br>  More you bet, more you have a chance to win the lottery.

The user who's playing can receive 100% of the prize (the 1POOL balance of LotteryPool).

_**The amount of the bet is burned, and will increase the deflation**_.

![1Pool Mechanism](https://i.ibb.co/kXrT1xd/1pool-mechanism.png)

## Lottery activation

Once the lottery is deployed, it is "stopped" to finish the front-end development and let the pool fill up.
<br>**This will be activated at a later stage.**

## Pool growth

As previously explained, 10% of the rewards go to the LotteryPool. But it can be adjusted between 5%
and 10% by calling `updatePoolRewardDivisor(uint256 _poolRewardDivisor) {...}`

## Pause

To allow time for the lottery to increase its reward, we included a "pause".
It means that if someone won the lottery, everyone has to wait **30 minutes** before being able to play again.

This duration can be changed by the owner. If 30 minutes is not enough, it can be set to 1 Hour (for example).

## Stop

A lottery means there are **security issues**, even if we use an oracle for random number generation. This is why the owner can stop/unstop the lottery to protect the fund, and avoid a hacker from dumping on everyone.

Stopping the lottery won't burn the funds, it will simply lock the "play" function.

## Fees / Oracle

![Bog Tools logo](https://bogtools.io/wp-content/uploads/2021/03/bogtools_logo_positive.svg)

We are using BogRNG from [Bog Tools](https://www.bogtools.io).
It allows applications to get Randomness On-Chain in a verifiably secure fashion.

**To play, the user need 0.25 BOG.**
[BUY HERE](https://exchange.pancakeswap.finance/#/swap?outputCurrency=0xd7b729ef857aa773f47d37088a1181bb3fbf0099&inputCurrency=BNB#).

## Latency 

Because the Oracle send a random number in a separate transaction, you are not playing in one transaction.
Once you played, the lottery is stated as "playing" and waiting for the oracle number. Between these blocks, nobody can play the lottery.

## Bet

As mentioned above, the bet is set by the user (except for fees).

**The user can't bet more than half of the prize.** For example, if the balance of the 
LotteryPool is 1000 1POOL, you can't bet more than 500 1POOL.

So what's the impact of a higher bet ?
<br>**If you want to bet the maximum amount, i.e 50% of the prize, you have a 50% chance to win.**

You can't bet 0 1POOL, however there is no minimum. You can bet 0,0000001 1POOL with a very low chance to win.

## 1POOL Token

1% of every transfer is burned to increase deflation.
<br>Otherwise, this is standard BEP-20 Token.

## Yield Farming

The Yield Farming part of this project (PoolMaster) is a fork of Sushiswap with some changes :
- The owner can't add more than one pool
- The dev fund can be disabled
- Removed massUpdatePool()

**So, why only ONE pool ?**

Because we want to focus the liquidity on a single pool, and remove non-1POOL pools.
<br>This way, even if the APY will decrease, it will be more viable in the long term.

## Initial Liquidity

If there is no non-1POOL pools, we can't mint the first tokens by farming.
<br>This is why the owner will receive 10.000 1POOLs (at the deployment) and be this first liquidity provider.

## 1POOL per block

The number of 1POOL per block is set to **1**.
<br>However it can be changed with `updateOnePoolPerBlock(uint256 _onePoolPerBlock) {...}` but only between 0.5 and 1.5.

## Dev Fund

2% of the Yield Farming rewards go to the dev fund.

``` javascript
if (devFundEnabled) {
    onepool.mint(devAddr, onePoolReward.div(50));
}
```

But this mecanism can be disabled ! Because we see that in most of Yield Farming projects,
the dev fund grows exponentially, and open the door for a rug pull.

By calling this function, the "dev" can disable the dev fund :

`function disableDevFund() external {...}`

> Disabling the dev fund is irreversible, it cannot be enabled again.

## Gas usage

_from : npx hardhat test_

![Gas report](https://i.ibb.co/zxbw9zm/gas-report.png)

## Unit tests

The project has been tested with unit tests. 

## Hardhat

To run this hardhat project, please use the following commands :

`npm install`

`npx hardhat compile`

`npx hardhat test`

## Contracts

- OnePoolToken => _Not deployed yet_
- LotteryPool => _Not deployed yet_
- PoolMaster => _Not deployed yet_

## Accounts

- Deployer => [_0xCA68C65CF332Eb855E7Bc680009eCf637e810149_](https://bscscan.com/address/0xCA68C65CF332Eb855E7Bc680009eCf637e810149)
- Dev Fund  => [_0xCCb073371c84c5Ef0d0E1F699aB58084D9514cC9_](https://bscscan.com/address/0xCCb073371c84c5Ef0d0E1F699aB58084D9514cC9)

