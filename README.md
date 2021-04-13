# ONEPOOL.FINANCE

*This repository contains the smart contracts and tests of onepool.finance project.
Any feedbacks or audits are welcome. For more information, please email us at onepoolfinance@gmail.com.*

## Introduction

onepool.finance is a Yield Farming/Lottery protocol on Binance Smart Chain, using the 1POOL token.

The protocol is split in two ideas : 
- Yield Farming, with only **one** pool : 1POOL/BNB
- A lottery without drawing lots, where you can win instantly.

## Mechanism

However, these two ideas are all together. 
<br> The Yield Farming protocol (*PoolMaster*) mints 1POOL tokens to the Lottery protocol
(LotteryPool). The prize is bigger if more people are farming.

> **10% of the rewards go to the LotteryPool**
> <br>`onepool.mint(lotteryPoolAddr, onePoolReward.div(10));`

All tokens in the pool are intended to be won. The user sets the  bet.
<br> The more you bet, the more you have a chance to win the lottery.

The user playing can receive 100% of the prize (the 1POOL balance of LotteryPool).

_**The bet is burned, and will increase the deflation**_.

![1Pool Mechanism](https://i.ibb.co/kXrT1xd/1pool-mechanism.png)

## Pause

## Stop

## Fees

## Restrictions

## Yield Farming





## BogTools Integration (Oracle)

## 1POOL Token

1% of every transfer is burned to increase deflation.
<br>Otherwise, this is standard ERC-20 Token.


