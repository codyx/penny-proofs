// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVerifiedAirdrop {
    function register() external;

    function play() external;

    function claim(bytes32[] calldata proof, bytes32 leaf) external;
}
