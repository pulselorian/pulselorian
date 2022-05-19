/*
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.9;

import "../uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

interface IPulseXRouter is IUniswapV2Router02 {
    function WPLS() external pure returns (address);
}
