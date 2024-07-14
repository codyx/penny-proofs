// Copyright 2024 RISC Zero, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// This application demonstrates how to send an off-chain proof request
// to the Bonsai proving service and publish the received proofs directly
// to your deployed app contract.

use alloy_primitives::Address;
use alloy_primitives::FixedBytes;
use alloy_sol_types::{sol, SolCall};
use anyhow::Result;
use apps::TxSender;
use clap::Parser;
use risc0_ethereum_contracts::groth16::encode;
use risc0_steel::{config::ETH_SEPOLIA_CHAIN_SPEC, ethereum::EthEvmEnv, Contract, EvmBlockHeader};
use risc0_zkvm::{default_prover, ExecutorEnv, ProverOpts, VerifierContext};
use tracing_subscriber::EnvFilter;
use verified_airdrop::VERIFIED_AIRDROP_ELF;

sol! {
    /// This must match the signature in the guest.
    interface ITarget {
        function readElements() external view returns (uint256[] memory);

        function buildMerkleTree(
            bytes calldata journalData,
            bytes calldata seal
        ) external payable;
    }
}

/// Arguments of the publisher CLI.
#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
struct Args {
    /// Ethereum chain ID
    #[clap(long)]
    chain_id: u64,

    /// Ethereum Node endpoint.
    #[clap(long, env)]
    eth_wallet_private_key: String,

    /// Ethereum Node endpoint.
    #[clap(long, env)]
    rpc_url: String,

    /// Counter's contract address on Ethereum
    #[clap(long)]
    contract: Address,
}

fn main() -> Result<()> {
    // Initialize tracing. In order to view logs, run `RUST_LOG=info cargo run`
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .init();

    // parse the command line arguments
    let args = Args::parse();

    println!("args: {:?}", args);

    // Create an EVM environment from an RPC endpoint and a block number. If no block number is
    // provided, the latest block is used.
    let mut env = EthEvmEnv::from_rpc(&args.rpc_url, None)?;
    //  The `with_chain_spec` method is used to specify the chain configuration.
    env = env.with_chain_spec(&ETH_SEPOLIA_CHAIN_SPEC);

    // Prepare the function call
    let call = ITarget::readElementsCall {};

    // Preflight the call to execute the function in the guest.
    let mut contract = Contract::preflight(args.contract, &mut env);
    let returns = contract.call_builder(&call).call()?;
    println!(
        "For block {} calling `{}` returns: {:?}",
        env.header().number(),
        ITarget::readElementsCall::SIGNATURE,
        returns._0
    );

    let values: Vec<FixedBytes<32>> = vec![
        FixedBytes::from([
            0x91, 0x3d, 0x8a, 0x51, 0x8f, 0xe9, 0x8d, 0x00, 0x31, 0x54, 0xb0, 0x68, 0x27, 0xd2,
            0x5d, 0x4f, 0xa6, 0xa0, 0x1a, 0xa6, 0x06, 0xea, 0xa6, 0x47, 0x1f, 0x5e, 0x24, 0x4e,
            0xc6, 0x46, 0x61, 0x77,
        ]),
        FixedBytes::from([
            0xca, 0x09, 0x51, 0xd5, 0xa3, 0x2b, 0x7c, 0xc7, 0x6a, 0xef, 0x97, 0x0d, 0x77, 0x9d,
            0x21, 0xd4, 0xb3, 0xe3, 0xf1, 0xa7, 0x57, 0xe3, 0xb3, 0x84, 0x2a, 0x61, 0x56, 0x90,
            0xf4, 0x78, 0x01, 0x05,
        ]),
        FixedBytes::from([
            0x9c, 0xe7, 0xda, 0x23, 0xe3, 0x9e, 0x4d, 0x25, 0x04, 0x17, 0x42, 0x74, 0x65, 0xf0,
            0x3f, 0x4f, 0x9e, 0xf2, 0x8c, 0xca, 0x35, 0xb1, 0xab, 0x8c, 0xe5, 0xfe, 0x83, 0xed,
            0xb3, 0x1c, 0x8f, 0xf0,
        ]),
        FixedBytes::from([
            0x6b, 0xdf, 0x8d, 0x0a, 0xf6, 0x86, 0xc5, 0xde, 0x60, 0xb4, 0xee, 0x53, 0xeb, 0x5c,
            0xbc, 0x51, 0x61, 0x3e, 0x94, 0xe8, 0xe2, 0xa2, 0x22, 0x02, 0xe9, 0x46, 0x5d, 0x31,
            0xb6, 0x0b, 0x42, 0xec,
        ]),
    ];

    println!("proving...");
    let view_call_input = env.into_input()?;
    let env = ExecutorEnv::builder()
        .write(&view_call_input)?
        .write(&args.contract)?
        .write(&values)?
        .build()?;

    let receipt = default_prover()
        .prove_with_ctx(
            env,
            &VerifierContext::default(),
            VERIFIED_AIRDROP_ELF,
            &ProverOpts::groth16(),
        )?
        .receipt;
    println!("proving...done");

    println!("receipt: {:?}", receipt);

    // Create a new `TxSender`.
    let tx_sender = TxSender::new(
        args.chain_id,
        &args.rpc_url,
        &args.eth_wallet_private_key,
        &args.contract.to_string(),
    )?;

    // Encode the groth16 seal with the selector
    let seal = encode(receipt.inner.groth16()?.seal.clone())?;
    println!("seal: {:?}", seal);

    let journal = receipt.journal.clone();

    println!("journal: {:?}", journal);

    // Encode the function call for `ITarget.buildMerkleTree(journal, seal)`.
    let calldata = ITarget::buildMerkleTreeCall {
        journalData: receipt.journal.bytes.into(),
        seal: seal.into(),
    }
    .abi_encode();

    // Send the calldata to Ethereum.
    println!("sending tx...");
    let runtime = tokio::runtime::Runtime::new()?;
    runtime.block_on(tx_sender.send(calldata))?;
    println!("sending tx...done");

    Ok(())
}
