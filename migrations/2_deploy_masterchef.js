/* global artifacts */
const Masterchef = artifacts.require('Masterchef')
const Lic = artifacts.require('Lic')

module.exports = async function(deployer, network, accounts) {
	const lic = await Lic.deployed();
  	await deployer.deploy(Masterchef, lic.address, accounts[0], '1000000000000000000', 0);
}
