# ONEPOOL.FINANCE

*This repository contains the smart contracts and tests of onepool.finance project.
Any feedbacks or audits are welcome. Use it at your own risk. For more information, please email us at onepoolfinance@gmail.com.*

## Introduction

onepool.finance is a Yield Farming/Lottery protocol on Binance Smart Chain, using the 1POOL token.

The protocol is split in two ideas : 
- Yield Farming, with only **one** pool : 1POOL/BNB
- A lottery without drawing lots, where you can win instantly.

## Mechanism

However, these two ideas are all together. 
<br> The Yield Farming protocol (*PoolMaster*) mints 1POOL tokens to the Lottery protocol
(LotteryPool). The prize is bigger as more people are farming.

> **10% of the rewards go to the LotteryPool**
> <br>`onepool.mint(lotteryPoolAddr, onePoolReward.div(10));`

All tokens in the pool are intended to be won. The user sets the  bet :
<br>  More you bet, more you have a chance to win the lottery.

The user who's playing can receive 100% of the prize (the 1POOL balance of LotteryPool).

_**The amount of the bet is burned, and will increase the deflation**_.

![1Pool Mechanism](https://i.ibb.co/kXrT1xd/1pool-mechanism.png)

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
Once you played, the lottery is stated as "playing" and waiting for the oracle number. Between this blocks, nobody can play the lottery.

## Bet

## 1POOL Token

1% of every transfer is burned to increase deflation.
<br>Otherwise, this is standard ERC-20 Token.

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

## Hardhat

To run this hardhat project, please use the following commands :

`npm install`

`npx hardhat compile`

`npx hardhat test`


