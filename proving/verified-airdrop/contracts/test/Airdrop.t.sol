// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import {Test} from "forge-std/Test.sol";
// import {console2} from "forge-std/console2.sol";

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// import {AirdropToken} from "../AirdropToken.sol";
// import {VerifiedAirdrop} from "../VerifiedAirdrop.sol";

// contract AirdropTester is Test {
//     using SafeERC20 for IERC20;

//     IERC20 public airdropToken;

//     VerifiedAirdrop public verifiedAirdrop;

//     address public bob = vm.addr(42);

//     event PlayerRegistered(address indexed player);

//     function setUp() public {
//         airdropToken = IERC20(
//             new AirdropToken("AirdropToken", "ADT", 1000000 ether)
//         );

//         address lzAuthorizedSender = vm.envAddress("LZ_AUTHORIZED_SENDER");
//         verifiedAirdrop = new VerifiedAirdrop(
//             lzAuthorizedSender,
//             address(airdropToken)
//         );

//         airdropToken.safeTransfer(
//             address(verifiedAirdrop),
//             airdropToken.totalSupply()
//         );
//     }

//     function testRegistration() public {
//         vm.startPrank(bob);

//         assertEq(verifiedAirdrop.playerCount(), 0);
//         assertEq(verifiedAirdrop.playerToPoints(bob), 0);

//         vm.expectEmit(true, true, true, true);
//         emit PlayerRegistered(bob);
//         verifiedAirdrop.register();

//         assertEq(
//             verifiedAirdrop.playerToPoints(bob),
//             verifiedAirdrop.REGISTRATION_BONUS_POINTS()
//         );
//         assertEq(verifiedAirdrop.playerCount(), 1);

//         vm.stopPrank();
//     }

//     function testAlreadyRegistered() public {
//         vm.startPrank(bob);

//         verifiedAirdrop.register();

//         vm.expectRevert("Already registered");
//         verifiedAirdrop.register();

//         vm.stopPrank();
//     }

//     function testRegisteringManyPlayers() public {
//         assertEq(verifiedAirdrop.playerCount(), 0);

//         for (uint256 playerIdx = 0; playerIdx < 100; ++playerIdx) {
//             address player = vm.addr(100 + playerIdx);
//             vm.prank(player);
//             verifiedAirdrop.register();
//         }
//         assertEq(verifiedAirdrop.playerCount(), 100);
//     }

//     function testPlay() public {
//         vm.startPrank(bob);

//         assertEq(verifiedAirdrop.playerToPoints(bob), 0);

//         verifiedAirdrop.register();
//         assertEq(
//             verifiedAirdrop.playerToPoints(bob),
//             verifiedAirdrop.REGISTRATION_BONUS_POINTS()
//         );

//         verifiedAirdrop.play();

//         assertTrue(
//             verifiedAirdrop.playerToPoints(bob) >
//                 verifiedAirdrop.REGISTRATION_BONUS_POINTS()
//         );

//         vm.stopPrank();
//     }

//     function testPlayManyPlayers() public {
//         for (uint256 playerIdx = 0; playerIdx < 100; ++playerIdx) {
//             address player = vm.addr(100 + playerIdx);
//             vm.startPrank(player);
//             verifiedAirdrop.register();
//             verifiedAirdrop.play();
//             verifiedAirdrop.play();
//             verifiedAirdrop.play();
//             vm.stopPrank();
//         }
//     }

//     function testClaim() public {
//         vm.prank(vm.envAddress("LZ_AUTHORIZED_SENDER"));
//         verifiedAirdrop.initMerkleRoot(
//             bytes32(
//                 0x7349362cc72e2ee72d726b233a90048fd7138ed2b81e60199f208e0cbaff16a3
//             )
//         );

//         vm.startPrank(bob);

//         verifiedAirdrop.register();

//         assertEq(airdropToken.balanceOf(bob), 0);

//         bytes32[] memory proof = new bytes32[](2);
//         proof[0] = bytes32(
//             0xd4dcc05668424e17ab885a7d240eacd41f16a1e7def0660eda5ac81bc87c654e
//         );
//         proof[1] = bytes32(
//             0x488435b15d1bfc3576cf235422f77ae3a2e7aa937d9da0c8c1e784d9d90d5a3e
//         );
//         bytes32 leaf = bytes32(
//             0xc36664f9fd0bfa749f21b373df798663ebffa818ff1948ce3820dfad46d510f2
//         );
//         verifiedAirdrop.claim(proof, leaf);

//         assertTrue(airdropToken.balanceOf(bob) > 0);

//         vm.stopPrank();
//     }

//     function testClaimUnsetMerkleRoot() public {
//         vm.startPrank(bob);

//         verifiedAirdrop.register();

//         vm.expectRevert("Merkle root not set");
//         verifiedAirdrop.claim(new bytes32[](0), bytes32(0));

//         vm.stopPrank();
//     }
// }
