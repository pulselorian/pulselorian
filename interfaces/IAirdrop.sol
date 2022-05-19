/*
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.9;

interface IAirdrop {
    function airdrop(address account, uint256 amount) external;
}
