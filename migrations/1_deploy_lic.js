/* global artifacts */
const Lic = artifacts.require('Lic')

module.exports = async function(deployer, network, accounts) {
	console.log('addr:', accounts[0])
	await deployer.deploy(Lic, accounts[0]);
}
