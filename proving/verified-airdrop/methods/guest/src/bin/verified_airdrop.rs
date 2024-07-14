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

#![allow(unused_doc_comments)]
#![no_main]

use alloy_primitives::Address;
use alloy_primitives::FixedBytes;
use alloy_sol_types::{sol, SolValue};
use hex;
use risc0_steel::{config::ETH_SEPOLIA_CHAIN_SPEC, ethereum::EthEvmInput, SolCommitment};
use risc0_zkvm::guest::env;
use std::collections::HashMap;
use tiny_keccak::{Hasher, Keccak};

risc0_zkvm::guest::entry!(main);

/// ABI encodable journal data.
sol! {
    struct Journal {
        SolCommitment commitment;
        bytes32 merkleRootHash;
    }
}

pub fn keccak256<T: AsRef<[u8]>>(bytes: T) -> [u8; 32] {
    let mut output = [0u8; 32];

    let mut hasher = Keccak::v256();
    hasher.update(bytes.as_ref());
    hasher.finalize(&mut output);

    output
}

#[derive(Debug)]
struct MerkleTree {
    tree: Vec<FixedBytes<32>>,
    hash_lookup: HashMap<String, usize>,
}

impl MerkleTree {
    fn new(data: Vec<FixedBytes<32>>) -> Self {
        let mut tree = MerkleTree {
            tree: vec![],
            hash_lookup: HashMap::new(),
        };
        tree.build(data);
        tree
    }

    fn build(&mut self, leaves: Vec<FixedBytes<32>>) {
        if leaves.is_empty() {
            return;
        }

        let mut tree = vec![FixedBytes::default(); 2 * leaves.len() - 1];

        for (i, leaf) in leaves.clone().into_iter().enumerate() {
            let index = tree.len() - 1 - i;
            tree[index] = alloy_primitives::FixedBytes(keccak256(leaf));
            self.hash_lookup.insert(hex::encode(keccak256(leaf)), index);
        }

        for i in (0..tree.len() - leaves.len()).rev() {
            tree[i] = alloy_primitives::FixedBytes(Self::hash_pair(
                &tree[Self::left_child_index(i)],
                &tree[Self::right_child_index(i)],
            ));
        }

        self.tree = tree;
    }

    fn left_child_index(i: usize) -> usize {
        2 * i + 1
    }

    fn right_child_index(i: usize) -> usize {
        2 * i + 2
    }

    fn hash_pair(left: &FixedBytes<32>, right: &FixedBytes<32>) -> [u8; 32] {
        let mut combined = Vec::with_capacity(64);
        let sorted = if left < right {
            (left, right)
        } else {
            (right, left)
        };
        combined.extend_from_slice(&sorted.0[..]);
        combined.extend_from_slice(&sorted.1[..]);
        keccak256(&combined)
    }

    pub fn get_root(&self) -> Option<FixedBytes<32>> {
        if self.tree.is_empty() {
            return None;
        }
        Some(self.tree[0])
    }
}

fn main() {
    // Read the input from the guest environment.
    let input: EthEvmInput = env::read();

    // Converts the input into a `EvmEnv` for execution. The `with_chain_spec` method is used
    // to specify the chain configuration. It checks that the state matches the state root in the
    // header provided in the input.
    let env = input.into_env().with_chain_spec(&ETH_SEPOLIA_CHAIN_SPEC);
    let contract: Address = env::read();
    println!("contract: {:?}", contract);

    let values: Vec<FixedBytes<32>> = env::read();

    let merkle_tree = MerkleTree::new(values);

    match merkle_tree.get_root() {
        Some(merkle_root_hash) => {
            println!("Merkle Root Hash: {}", merkle_root_hash);

            // Commit the block hash and number used when deriving `view_call_env` to the journal.
            let journal = Journal {
                commitment: env.block_commitment(),
                merkleRootHash: merkle_root_hash,
            };
            env::commit_slice(&journal.abi_encode());
        }
        None => {
            panic!("Merkle Root Hash is empty");
        }
    };
}
