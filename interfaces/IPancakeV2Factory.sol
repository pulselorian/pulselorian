/*
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.9;

interface IPancakeV2Factory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}