// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IVerifiedAirdrop} from "./IVerifiedAirdrop.sol";

contract VerifiedAirdrop is IVerifiedAirdrop {
    uint256 public constant REGISTRATION_BONUS_POINTS = 100;

    mapping(uint256 => address) public players;

    mapping(address => uint256) public playerToPoints;

    uint256 public playerCount;

    bytes32 public merkleRoot;

    bool public merkleRootSet;

    address public immutable lzAuthorizedSender;

    IERC20 public immutable airdropToken;

    error AlreadyRegistered();

    using SafeERC20 for IERC20;

    event PlayerRegistered(address indexed player);

    constructor(address _lzAuthorizedSender, address _airdropToken) {
        lzAuthorizedSender = _lzAuthorizedSender;
        airdropToken = IERC20(_airdropToken);

        merkleRootSet = false;
    }

    modifier onlyLzAuthorizedSender() {
        require(msg.sender == lzAuthorizedSender, "Not authorized");
        _;
    }

    function initMerkleRoot(
        bytes32 _merkleRoot
    ) external onlyLzAuthorizedSender {
        require(!merkleRootSet, "Merkle root already set");

        merkleRoot = _merkleRoot;
        merkleRootSet = true;
    }

    function register() external {
        require(playerToPoints[msg.sender] == 0, "Already registered");

        // Register the player.
        players[playerCount] = msg.sender;
        playerToPoints[msg.sender] = REGISTRATION_BONUS_POINTS;
        ++playerCount;

        emit PlayerRegistered(msg.sender);
    }

    modifier onlyPlayers() {
        require(playerToPoints[msg.sender] > 0, "Not registered");
        _;
    }

    function play() external onlyPlayers {
        // Simulate a random number generation (insecure).
        uint256 insecureRandomPointsToAward = (uint(
            keccak256(
                abi.encodePacked(block.timestamp, block.number, msg.sender)
            )
        ) % 91) + 10;

        // Award the player with the pseudo-random points.
        playerToPoints[msg.sender] += insecureRandomPointsToAward;
    }

    function claim(
        bytes32[] calldata proof,
        bytes32 leaf
    ) external onlyPlayers {
        require(merkleRootSet, "Merkle root not set");

        require(
            MerkleProof.verify(proof, merkleRoot, leaf),
            "Invalid Merkle proof"
        );

        uint256 points = playerToPoints[msg.sender];
        playerToPoints[msg.sender] = 0;
        airdropToken.safeTransfer(msg.sender, points * 10 ** 18);
    }
}
