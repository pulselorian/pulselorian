/**
 * author: ThePulseLorian <pulselorian@gmail.com>
 * telegram: https://t.me/ThePulselorian
 * twitter: https://twitter.com/ThePulseLorian
 *
 * BESKHA
 *
 * This token's base source code comes from Safemoon.
 * It's has several changes to the tokenomics to make it a better internet currency
 * It's deflationary, has reflection or auto-staking feature, has burn feature,
 * includes automatic lottery and lot more
 * Visit https://www.pulselorian.com for more details
 *
 * - BSKRv5 audit
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
 * Marketing        1.0%
 * Liquidity        0.5%
 * Lottery          0.5%
 */

contract BSKRv5 is Beskar {
    constructor() Beskar(Env.Testnet) {
        // pre-approve the initial liquidity supply (to safe a bit of time)
        _approve(owner(), address(_router), ~uint256(0));
    }
}

/**
 * Todo (beta):
 *
 * - reorganize the sol file(s) to make put everything editable in a single .sol file
 *      and keep all other code in other .sol file(s)
 * - move variable values initialized in the contract to be constructor parameters
 * - add/remove setters/getter where appropriate
 * - add unit tests (via ganache-cli + truffle)
 * - add full dev evn (truffle) folders & files
 *
 * Todo:
 *
 * - implement `_takeFeeToETH` (currently just calls `_takeFee`)
 * - implement anti whale mechanics (via different pre-created libraries?), eg progressive tax
 * - implement anti sell mechanics
 * - address SSL-04 | Centralized risk in addLiquidity - https://www.certik.org/projects/safemoon
 *      change the recipient to `address(this)` or implement a decentralized mechanism or
 *      smart-contract solution
 * - change Uniswap to PancakeSwap in contract/interface names and local var names
 * - change ETH to BNB in names and comments
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
 * - ETH/BNB collected/stuck in the contract can be withdrawn (see)
 */