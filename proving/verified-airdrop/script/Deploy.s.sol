// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IRiscZeroVerifier} from "risc0/IRiscZeroVerifier.sol";
import {ControlID, RiscZeroGroth16Verifier} from "risc0/groth16/RiscZeroGroth16Verifier.sol";

import {VerifiedAirdrop} from "../contracts/VerifiedAirdrop.sol";
import {AirdropToken} from "../contracts/AirdropToken.sol";

/// @notice Deployment script for the VerifiedAirdrop contract.
/// @dev Use the following environment variable to control the deployment:
///     * ETH_WALLET_PRIVATE_KEY private key of the wallet to be used for deployment.
///     * LZ_AUTHORIZED_SENDER address of the authorized sender.
///
contract VerifiedAirdropDeployer is Script {
    function run() external {
        uint256 deployerKey = uint256(vm.envBytes32("ETH_WALLET_PRIVATE_KEY"));

        vm.startBroadcast(deployerKey);

        AirdropToken airdropToken = new AirdropToken(
            "AirdropToken",
            "ADT",
            1000000 ether
        );
        console2.log("Deployed AirdropToken to", address(airdropToken));

        address lzAuthorizedSender = vm.envAddress("LZ_AUTHORIZED_SENDER");
        VerifiedAirdrop verifiedAirdrop = new VerifiedAirdrop(
            lzAuthorizedSender,
            address(airdropToken)
        );
        console2.log("Deployed VerifiedAirdrop to", address(verifiedAirdrop));

        vm.stopBroadcast();
    }
}
