// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPennyProofVerfiedAirdrop {
    function buildMerkleTree(
        bytes calldata journalData,
        bytes calldata seal
    ) external;
}
