/*
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.9;

abstract contract Airdrop {
    function airdrop(address account, uint256 amount) external virtual;
}
