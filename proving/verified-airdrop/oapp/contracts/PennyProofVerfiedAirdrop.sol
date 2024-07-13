// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import { IRiscZeroVerifier } from "./interfaces/IRiscZeroVerifier.sol";
import { Steel } from "./Steel.sol";
import { ImageID } from "./ImageID.sol"; // auto-generated contract after running `cargo build`.
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { OApp, MessagingFee, Origin } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import { MessagingReceipt } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppSender.sol";
import { IPennyProofVerfiedAirdrop } from "./IPennyProofVerfiedAirdrop.sol";

import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract PennyProofVerfiedAirdrop is OApp, IPennyProofVerfiedAirdrop {
    constructor(address _endpoint, address _delegate, address _verifier) OApp(_endpoint, _delegate) Ownable(_delegate) {
        verifier = IRiscZeroVerifier(_verifier);
    }

    using OptionsBuilder for bytes;
    using Strings for bytes32;

    struct Journal {
        Steel.Commitment commitment;
        bytes32 merkleRootHash;
    }

    /// @notice Image ID of the only zkVM binary to accept verification from.
    bytes32 public constant imageId = ImageID.VERIFIED_AIRDROP_ID;

    /// @notice RISC Zero verifier contract address.
    IRiscZeroVerifier public immutable verifier;

    uint32 constant eidSepolia = 40161;
    uint32 constant eidAmoy = 40267;

    /**
     * @notice Sends a message from the source chain to a destination chain.
     * @param _dstEid The endpoint ID of the destination chain.
     * @param _message The message string to be sent.
     * @param _options Additional options for message execution.
     * @dev Encodes the message as bytes and sends it using the `_lzSend` internal function.
     * @return receipt A `MessagingReceipt` struct containing details of the message sent.
     */
    function send(
        uint32 _dstEid,
        string memory _message,
        bytes memory _options
    ) public payable onlyOwner returns (MessagingReceipt memory receipt) {
        bytes memory _payload = abi.encode(_message);
        receipt = _lzSend(_dstEid, _payload, _options, MessagingFee(msg.value, 0), payable(msg.sender));
    }

    /**
     * @notice Quotes the gas needed to pay for the full omnichain transaction in native gas or ZRO token.
     * @param _dstEid Destination chain's endpoint ID.
     * @param _message The message.
     * @param _options Message execution options (e.g., for sending gas to destination).
     * @param _payInLzToken Whether to return fee in ZRO token.
     * @return fee A `MessagingFee` struct containing the calculated gas fee in either the native token or ZRO token.
     */
    function quote(
        uint32 _dstEid,
        string memory _message,
        bytes memory _options,
        bool _payInLzToken
    ) public view returns (MessagingFee memory fee) {
        bytes memory payload = abi.encode(_message);
        fee = _quote(_dstEid, payload, _options, _payInLzToken);
    }

    function createLzReceiveOption(uint128 _gas, uint128 _value) public pure returns (bytes memory) {
        return OptionsBuilder.newOptions().addExecutorLzReceiveOption(_gas, _value);
    }

    /// @notice Removes duplicates (if any) from the original array and returns the new array.
    /// @dev The Steel proof must be generated off-chain using RISC0-zkVM and submitted here.
    function buildMerkleTree(bytes calldata journalData, bytes calldata seal) external onlyOwner {
        Journal memory journal = abi.decode(journalData, (Journal));

        require(Steel.validateCommitment(journal.commitment), "Invalid commitment");

        // Verify the proof
        bytes32 journalHash = sha256(journalData);
        verifier.verify(seal, PennyProofVerfiedAirdrop.imageId, journalHash);

        MessagingFee memory fee = quote(
            eidSepolia,
            Strings.toHexString(uint256(bytes32(0x0))),
            createLzReceiveOption(0, 0),
            false
        );

        //send message via lz
        bytes memory _options = createLzReceiveOption(uint128(fee.nativeFee), 0);

        // convert journal.merkleRootHash to bytes

        // string memory message = Strings.toHexString(uint256(journal.merkleRootHash));
        send(eidSepolia, Strings.toHexString(uint256(journal.merkleRootHash)), _options);
    }

    // function endpoint() external view override returns (ILayerZeroEndpointV2 iEndpoint) {}

    // function peers(uint32 _eid) external view returns (bytes32 peer) {}

    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) internal virtual override {}
}
