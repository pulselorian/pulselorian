/**
 * author: ThePulseLorian <pulselorian@gmail.com>
 * telegram: https://t.me/ThePulselorian
 * twitter: https://twitter.com/ThePulseLorian
 *
 * BSKR (B3SKAR)
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
 *    (   (  (  (     (   (( (   .  (   (    (( (   ((
 *    )\  )\ )\ )\    )\ (\())\   . )\  )\   ))\)\  ))\
 *   ((_)((_)(_)(_)  ((_))(_)(_)   ((_)((_)(((_)_()((_)))
 *   | _ \ | | | |  / __| __| |   / _ \| _ \_ _|   \ \| |
 *   |  _/ |_| | |__\__ \ _|| |__| (_) |   /| || - | .  |
 *   |_|  \___/|____|___/___|____|\___/|_|_\___|_|_|_|\_|
 *
 *
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.9;

import "./abstracts/Beskar.sol";

/**
 * Tokenomics:
 *
 * Reflection       2.0%      36%     
 * Burn             1.5%      27%
 * Growth           1.0%      18%
 * Liquidity        0.5%       9%
 * Lottery          0.5%       9%
 */

contract BSKR is Beskar {
    constructor() Beskar(Env.PLSTestnetv2b) {
        // pre-approve the initial liquidity supply
        _approve(owner(), address(_router), ~uint256(0));
    }
}