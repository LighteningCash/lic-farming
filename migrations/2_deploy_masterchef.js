/* global artifacts */
const Masterchef = artifacts.require('Masterchef')
const Lic = artifacts.require('Lic')
const BN = require('bignumber.js')
BN.config({ DECIMAL_PLACES: 0 })
BN.config({ ROUNDING_MODE: BN.ROUND_DOWN })
const { expectRevert, time } = require('@openzeppelin/test-helpers')

module.exports = async function(deployer, network, accounts) {
	const lic = await Lic.deployed();
  	await deployer.deploy(Masterchef, lic.address, accounts[0], 0);
}
