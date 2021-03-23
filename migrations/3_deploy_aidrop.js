/* global artifacts */
const Airdrop = artifacts.require('Airdrop')

module.exports = async function(deployer, network, accounts) {
	await deployer.deploy(Airdrop);
}
