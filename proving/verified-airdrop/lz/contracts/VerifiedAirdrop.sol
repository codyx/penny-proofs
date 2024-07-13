// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { OApp, MessagingFee, Origin } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import { MessagingReceipt } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppSender.sol";

import { IVerifiedAirdrop } from "./IVerifiedAirdrop.sol";

contract VerifiedAirdrop is OApp, IVerifiedAirdrop {
    using SafeERC20 for IERC20;

    uint256 public constant REGISTRATION_BONUS_POINTS = 100;

    mapping(uint256 => address) public players;

    mapping(address => uint256) public playerToPoints;

    uint256 public playerCount;

    bytes32 public merkleRoot;

    bool public merkleRootSet;

    address public immutable lzAuthorizedSender;

    IERC20 public immutable airdropToken;

    error AlreadyRegistered();

    event PlayerRegistered(address indexed player);

    constructor(
        address _endpoint,
        address _delegate,
        address _airdropToken
    ) OApp(_endpoint, _delegate) Ownable(_delegate) {
        airdropToken = IERC20(_airdropToken);
        merkleRootSet = false;
    }

    /**
     * @dev Internal function override to handle incoming messages from another chain.
     * @dev _origin A struct containing information about the message sender.
     * @dev _guid A unique global packet identifier for the message.
     * @param payload The encoded message payload being received.
     *
     * @dev The following params are unused in the current implementation of the OApp.
     * @dev _executor The address of the Executor responsible for processing the message.
     * @dev _extraData Arbitrary data appended by the Executor to the message.
     *
     * Decodes the received payload and processes it as per the business logic defined in the function.
     */
    function _lzReceive(
        Origin calldata /*_origin*/,
        bytes32 /*_guid*/,
        bytes calldata payload,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override {
        require(!merkleRootSet, "Merkle root already set");

        merkleRoot = abi.decode(payload, (bytes32));
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
            keccak256(abi.encodePacked(block.timestamp, block.number, msg.sender))
        ) % 91) + 10;

        // Award the player with the pseudo-random points.
        playerToPoints[msg.sender] += insecureRandomPointsToAward;
    }

    function claim(bytes32[] calldata proof, bytes32 leaf) external onlyPlayers {
        require(merkleRootSet, "Merkle root not set");

        require(MerkleProof.verify(proof, merkleRoot, leaf), "Invalid Merkle proof");

        uint256 points = playerToPoints[msg.sender];
        playerToPoints[msg.sender] = 0;
        airdropToken.safeTransfer(msg.sender, points * 10 ** 18);
    }
}
