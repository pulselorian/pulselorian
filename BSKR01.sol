/**
 * author: ThePulseLorian <pulselorian@gmail.com>
 * telegram: https://t.me/ThePulselorian
 * twitter: https://twitter.com/ThePulseLorian
 *
 * BESKHA
 *
 * BSKR's source code borrows some features/code from Safemoon.
 * It's has several changes to the tokenomics to make it a better internet currency
 * It's deflationary, has reflection or auto-staking feature, has burn feature,
 * includes automatic lottery and lot more
 * Visit https://www.pulselorian.com for more details
 *
 * - BSKR audit
 *      <Audit report link to be added here>
 *
 *
 * (   (  (  (     (   (( (   .  (   (    (( (   ((
 * )\  )\ )\ )\    )\ (\())\   . )\  )\   ))\)\  ))\
 *((_)((_)(_)(_)  ((_))(_)(_)   ((_)((_)(((_)_()((_)))
 *| _ \ | | | |  / __| __| |   / _ \| _ \_ _|   \ \| |
 *|  _/ |_| | |__\__ \ _|| |__| (_) |   /| || - | .  |
 *|_|  \___/|____|___/___|____|\___/|_|_\___|_|_|_|\_|
 *
 *
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.9;

import "./abstracts/Beskar.sol";

/**
 * Tokenomics:
 *
 * Reflection       2.0%
 * Burn             1.5%
 * Marketing        0.5%
 * Liquidity        0.5%
 * Lottery          0.5%
 */

contract BSKRv6 is Beskar {
    constructor() Beskar(Env.PLSTestnetv2b) {
        // pre-approve the initial liquidity supply (to safe a bit of time)
        _approve(owner(), address(_router), ~uint256(0));
    }
}

/**
 *
 * - implement `_takeFeeToNativeToken` (currently just calls `_takeFee`)
 * - implement anti whale mechanics (via different pre-created libraries?), eg progressive tax
 * - implement anti sell mechanics
 * - address SSL-04 | Centralized risk in addLiquidity - certik.org finding
 *      change the recipient to `address(this)` or implement a decentralized mechanism or
 *      smart-contract solution
 */

/**
 * Tests to pass:
 *
 * - Tokenomics fees can be added/removed/edited
 * - Tokenomics fees are correctly taken from each (qualifying) transaction
 * - The RFI fee is correctly distributed among holders (which are not excluded from rewards)
 * - `swapAndLiquify` works correctly when the threshold balance is reached
 * - `maxTransactionAmount` works correctly and *unlimited* accounts are not subject to the limit
 * - `maxWalletBalance` works correctly and *unlimited* accounts are not subject to the limit
 * - accounts excluded from fees are not subjecto tx fees
 * - accounts excluded from rewards do not share in rewards
 */