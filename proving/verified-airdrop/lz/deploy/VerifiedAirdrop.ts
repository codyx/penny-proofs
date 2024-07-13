import assert from 'assert'

import { type DeployFunction } from 'hardhat-deploy/types'

const contractName = 'VerifiedAirdrop'

const deploy: DeployFunction = async (hre) => {
    const { getNamedAccounts, deployments } = hre

    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    assert(deployer, 'Missing named deployer account')

    console.log(`Network: ${hre.network.name}`)
    console.log(`Deployer: ${deployer}`)

    // This is an external deployment pulled in from @layerzerolabs/lz-evm-sdk-v2
    //
    // @layerzerolabs/toolbox-hardhat takes care of plugging in the external deployments
    // from @layerzerolabs packages based on the configuration in your hardhat config
    //
    // For this to work correctly, your network config must define an eid property
    // set to `EndpointId` as defined in @layerzerolabs/lz-definitions
    //
    // For example:
    //
    // networks: {
    //   fuji: {
    //     ...
    //     eid: EndpointId.AVALANCHE_V2_TESTNET
    //   }
    // }
    const endpointV2Deployment = await hre.deployments.get('EndpointV2')

    const airdropTokenFactory = await hre.ethers.getContractFactory('AirdropToken')
    const airdropToken = await airdropTokenFactory.deploy('AirdropToken', 'AT', '1000000')

    console.log(`Deployed AirdropToken: ${airdropToken.address}`)

    //print nonce
    const nonceBefore = await hre.ethers.provider.getTransactionCount(deployer)
    console.log(`Nonce: ${nonceBefore}`)

    const { address } = await deploy(contractName, {
        from: deployer,
        args: [
            endpointV2Deployment.address, // LayerZero's EndpointV2 address
            deployer, // owner
            airdropToken.address, // token address
        ],
        log: true,
        skipIfAlreadyDeployed: false,
        gasPrice: '360000000000',
        nonce: nonceBefore + 1,
    })

    //console log nonce
    const nonce = await hre.ethers.provider.getTransactionCount(deployer)
    console.log(`Nonce: ${nonce}`)

    console.log(`Deployed contract: ${contractName}, network: ${hre.network.name}, address: ${address}`)

    const tx = await airdropToken.transfer(address, '1000000')
    await tx.wait(10)

    // Verify the contract on Etherscan
    console.log('Verifying contract on Etherscan...')
    await hre.run('verify:verify', {
        address: address,
        constructorArguments: [endpointV2Deployment.address, deployer, airdropToken.address],
    })
}

deploy.tags = [contractName]

export default deploy
