/* global artifacts */
const Lic = artifacts.require('Lic')

module.exports = async function(deployer, network, accounts) {
	await deployer.deploy(Lic, accounts[0]);
}
