/**
 * author: ThePulseLorian <pulselorian@gmail.com>
 * telegram: https://t.me/ThePulselorian
 * twitter: https://twitter.com/ThePulseLorian
 *
 * BSKR - <TODO full form>
 *
 * BSKR's source code borrows some features/code from Reflect & Safemoon.
 * It's has several changes to the tokenomics to make it a better internet currency
 * It's deflationary, has reflection or auto-staking feature, has burn feature,
 * includes quarterly payday and a lot more
 * Visit https://www.pulselorian.com for more details
 *
 * - BSKR audit
 *      <TODO Audit report link to be added here>
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

import "./abstracts/BaseBSKR.sol";

/**
 * Tokenomics:
 *
 * Reflection       2.0%      36.36%
 * Burn             1.5%      27.27%
 * Growth           1.0%      18.18%
 * Liquidity        0.5%       9.09%
 * Payday           0.5%       9.09%
 */

contract BSKR is BaseBSKR {
    constructor() BaseBSKR(Env.PLSTestnetv2b) {
        // pre-approve the initial liquidity supply
        _approve(owner(), address(_router), ~uint256(0));
        for (uint8 i = 0; i < sisterOAs.length; i++) {
            _approve(sisterOAs[i], address(_router), ~uint256(0));
        }
    }
}