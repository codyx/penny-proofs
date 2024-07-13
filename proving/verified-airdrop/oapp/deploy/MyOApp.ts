import assert from 'assert'
import { ethers } from 'hardhat'
import { type DeployFunction } from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

// Contract names
const contractNames = {
    PennyProofVerfiedAirdrop: 'PennyProofVerfiedAirdrop',
    RiscZeroGroth16Verifier: 'RiscZeroGroth16Verifier',
}

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { getNamedAccounts, deployments } = hre
    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    assert(deployer, 'Missing named deployer account')

    console.log(`Network: ${hre.network.name}`)
    console.log(`Deployer: ${deployer}`)

    // Deploy EndpointV2
    const endpointV2Deployment = await hre.deployments.get('EndpointV2')

    // Deploy RiscZeroGroth16Verifier
    const { address: verifierAddress } = await deploy(contractNames.RiscZeroGroth16Verifier, {
        from: deployer,
        args: [
            ethers.utils.id('a516a057c9fbf5629106300934d48e0e775d4230e41e503347cad96fcbde7e2e'), // Replace with actual CONTROL_ROOT if available
            ethers.utils.id('0eb6febcf06c5df079111be116f79bd8c7e85dc9448776ef9a59aaf2624ab551'), // Replace with actual BN254_CONTROL_ID if available
        ],
        log: true,
        skipIfAlreadyDeployed: false,
    })

    console.log(
        `Deployed contract: ${contractNames.RiscZeroGroth16Verifier}, network: ${hre.network.name}, address: ${verifierAddress}`
    )

    // Deploy PennyProofVerfiedAirdrop
    const { address: myOAppAddress } = await deploy(contractNames.PennyProofVerfiedAirdrop, {
        from: deployer,
        args: [
            endpointV2Deployment.address, // LayerZero's EndpointV2 address
            deployer, // owner
            verifierAddress, // RISC Zero verifier address
        ],
        log: true,
        skipIfAlreadyDeployed: false,
    })

    console.log(
        `Deployed contract: ${contractNames.PennyProofVerfiedAirdrop}, network: ${hre.network.name}, address: ${myOAppAddress}`
    )
}

deploy.tags = Object.values(contractNames)

export default deploy
