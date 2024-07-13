import { ethers, getNamedAccounts } from 'hardhat'

async function main() {
    const { deployer } = await getNamedAccounts()

    // Define the addresses for the deployed contracts
    const myOAppAddressRemote = '0xd842f6bF30E5DA6FcDBE17E7b769969DB556cD36'

    const myOAppAddressLocal = '0xC592c7bB3b664B9E093d62B8Efd429b1B2EF21D1'

    // Get the contract factory for MyOApp
    const MyOAppLocal = await ethers.getContractFactory('PennyProofVerfiedAirdrop', deployer)

    // Connect to the deployed contracts on Sepolia
    const myOApp = await MyOAppLocal.attach(myOAppAddressLocal)

    // Read the merkleRootHash from the deployed contracts
    // const merkleRootHash = await myOApp.merkleRootHash()

    // Log the merkleRootHash values
    // console.log(`Merkle Root Hash : ${merkleRootHash}`)

    //print network
    const network = await ethers.provider.getNetwork()

    const eidSepolia = 40161
    const eidAmoy = 40267

    if (network.chainId === 11155111) {
        // sepolia
        const peersSepolia = await myOApp.peers(eidAmoy)
        console.log(`Peers on Sepolia: ${peersSepolia}`)

        if (peersSepolia == '0x0000000000000000000000000000000000000000000000000000000000000000') {
            console.log('Setting peer')
            await myOApp.setPeer(eidAmoy, ethers.utils.zeroPad(myOAppAddressRemote, 32))
        }
    } else {
        if (network.chainId === 80002) {
            //amoy
            const peersAmoy = await myOApp.peers(eidSepolia)
            console.log(`Peers on Amoy: ${peersAmoy}`)
            if (peersAmoy == '0x0000000000000000000000000000000000000000000000000000000000000000') {
                console.log('Setting peer')
                await myOApp.setPeer(eidSepolia, ethers.utils.zeroPad(myOAppAddressRemote, 32))
            }
        }
    }

    // await myOApp.setPeer(2, ethers.utils.zeroPad(myOAppB.address, 32))
    // await myOAppB.setPeer(1, ethers.utils.zeroPad(myOAppA.address, 32))
}

// Run the script with error handling
main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
