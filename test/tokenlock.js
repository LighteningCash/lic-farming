const { expectRevert, time } = require('@openzeppelin/test-helpers');
const BN = require('bignumber.js');
BN.config({ DECIMAL_PLACES: 0 })
BN.config({ ROUNDING_MODE: BN.ROUND_DOWN })
const Lic = artifacts.require('Lic');
const Masterchef = artifacts.require('Masterchef');
const MockERC20 = artifacts.require('MockERC20');
const TimeLock = artifacts.require('TimeLock');

function toWei(n) {
	return new BN(n).multipliedBy(new BN('1e18')).toFixed(0);
}

let deployer
let accounts
let nullAcc = "0x0000000000000000000000000000000000000000"

async function assertHarvest(t, addr, pid) {
	const lastRewardBlock = (await t.masterchef.lastRewardBlock()).valueOf().toString();
	const currentBlock = await time.latestBlock();
	const numBlock = new BN(currentBlock).minus(lastRewardBlock).plus(1).toFixed(0);
	const totalPendingRewards = new BN(numBlock).multipliedBy(5*3).multipliedBy(new BN('1e18'));
	const pendingReward = totalPendingRewards.multipliedBy(85).dividedBy(100).toFixed(0);

	let devReward = new BN(pendingReward).multipliedBy(5).dividedBy(85).toFixed();

	const referrers = (await t.masterchef.getReferers(addr)).valueOf();
	if (referrers.ref1 == nullAcc) {
		//all refs are forwarded to dev reward
		devReward = new BN(devReward).plus(new BN(pendingReward).multipliedBy(10).dividedBy(85)).toFixed(0);
	} else if (referrers.ref2 == nullAcc) {
		//all ref lv2 are forwarded to dev reward
		devReward = new BN(devReward).plus(new BN(pendingReward).multipliedBy(3).dividedBy(85)).toFixed(0);
	}

	const devAddr = (await t.masterchef.devaddr()).valueOf().toString();

	let devBefore = (await t.lic.balanceOf(devAddr)).valueOf().toString();
	let before = (await t.lic.balanceOf(addr)).valueOf().toString();
	await t.masterchef.withdraw(pid, 0, {from: addr});
	let after = (await t.lic.balanceOf(addr)).valueOf().toString();
	let devAfter = (await t.lic.balanceOf(devAddr)).valueOf().toString();
	assert.equal(new BN(after).minus(new BN(before)).valueOf().toString(), new BN(pendingReward).multipliedBy(235).dividedBy(1000).toFixed(0));
	assert.equal(new BN(devAfter).minus(new BN(devBefore)).valueOf().toString(), new BN(devReward).multipliedBy(235).dividedBy(1000).toFixed(0));
} 

async function assertHarvestPending(t, addr, pid) {
	const pendingReward = (await t.masterchef.pendingLicAtNextBlock(pid, addr)).valueOf().toString();

	let before = (await t.lic.balanceOf(addr)).valueOf().toString();
	await t.masterchef.withdraw(pid, 0, {from: addr});
	let after = (await t.lic.balanceOf(addr)).valueOf().toString();
	assert.equal(new BN(after).minus(new BN(before)).valueOf().toString(), new BN(pendingReward).multipliedBy(235).dividedBy(1000).toFixed(0));
	return pendingReward;
} 

async function assertHarvestPendingNoAssert(t, addr, pid) {
	const pendingReward = (await t.masterchef.pendingLicAtNextBlock(pid, addr)).valueOf().toString();

	let before = (await t.lic.balanceOf(addr)).valueOf().toString();
	await t.masterchef.withdraw(pid, 0, {from: addr});
	let after = (await t.lic.balanceOf(addr)).valueOf().toString();
	return pendingReward;
} 

contract('Token Lock', (allAccounts) => {
	deployer = allAccounts[0];
	accounts = allAccounts.slice(1);
	let ref0 = allAccounts[200];
	let ref1 = allAccounts[201];
    beforeEach(async () => {
        this.lic = await Lic.new(deployer, {from: deployer});
		this.masterchef = await Masterchef.new(this.lic.address, deployer, 0, {from: deployer});
    });

	it('Token unlock airdrop', async () => {
		//total unlock at TGE = 1.2M + 2.5M + 6M = 9.7M
		assert.equal(new BN('9700000e18').toFixed(0), (await this.lic.balanceOf(deployer)).valueOf().toString());

		await time.increase(1);
		//unlock airdrop
		let balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseAirdrop({from: deployer});
		let balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(balBefore, balAfter);

		await time.increase(86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseAirdrop({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(600000)).toFixed(0), balAfter);

		await time.increase(86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseAirdrop({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(600000)).toFixed(0), balAfter);

		await time.increase(86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseAirdrop({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(600000)).toFixed(0), balAfter);

		await time.increase(86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseAirdrop({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(600000)).toFixed(0), balAfter);

		await time.increase(86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseAirdrop({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(600000)).toFixed(0), balAfter);

		await time.increase(86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseAirdrop({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(600000)).toFixed(0), balAfter);

		await time.increase(86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseAirdrop({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(600000)).toFixed(0), balAfter);

		await time.increase(86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseAirdrop({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(600000)).toFixed(0), balAfter);

		await time.increase(86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseAirdrop({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(balBefore, balAfter);
	});

	it('Token unlock team', async () => {
		//total unlock at TGE = 1.2M + 2.5M + 6M = 9.7M
		assert.equal(new BN('9700000e18').toFixed(0), (await this.lic.balanceOf(deployer)).valueOf().toString());

		await time.increase(1);
		//unlock airdrop
		let balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseTeam({from: deployer});
		let balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(balBefore, balAfter);

		await time.increase(9 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseTeam({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(balBefore, balAfter);

		await time.increase(3 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseTeam({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(300000)).toFixed(0), balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseTeam({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(300000)).toFixed(0), balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseTeam({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(300000)).toFixed(0), balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseTeam({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(300000)).toFixed(0), balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseTeam({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(300000)).toFixed(0), balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseTeam({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(300000)).toFixed(0), balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseTeam({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(300000)).toFixed(0), balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseTeam({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(300000)).toFixed(0), balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseTeam({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(300000)).toFixed(0), balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseTeam({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(300000)).toFixed(0), balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseTeam({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(balBefore, balAfter);
	});

	it('Token unlock development', async () => {
		//total unlock at TGE = 1.2M + 2.5M + 6M = 9.7M
		assert.equal(new BN('9700000e18').toFixed(0), (await this.lic.balanceOf(deployer)).valueOf().toString());

		await time.increase(1);
		//unlock airdrop
		let balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseDevelopment({from: deployer});
		let balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(balBefore, balAfter);

		await time.increase(5 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseDevelopment({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(balBefore, balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseDevelopment({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(500000)).toFixed(0), balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseDevelopment({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(500000)).toFixed(0), balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseDevelopment({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(500000)).toFixed(0), balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseDevelopment({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(500000)).toFixed(0), balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseDevelopment({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(500000)).toFixed(0), balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseDevelopment({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(500000)).toFixed(0), balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseDevelopment({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(500000)).toFixed(0), balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseDevelopment({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(500000)).toFixed(0), balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseDevelopment({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(500000)).toFixed(0), balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseDevelopment({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(500000)).toFixed(0), balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseDevelopment({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(balBefore, balAfter);
	});

	it('Token unlock ecosystem', async () => {
		//total unlock at TGE = 1.2M + 2.5M + 6M = 9.7M
		assert.equal(new BN('9700000e18').toFixed(0), (await this.lic.balanceOf(deployer)).valueOf().toString());

		await time.increase(1);
		//unlock airdrop
		let balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseEcosystem({from: deployer});
		let balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(balBefore, balAfter);

		await time.increase(5 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseEcosystem({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(balBefore, balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseEcosystem({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(7500000)).toFixed(0), balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseEcosystem({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(balBefore, balAfter);
	});

	it('Token unlock advisor', async () => {
		//total unlock at TGE = 1.2M + 2.5M + 6M = 9.7M
		assert.equal(new BN('9700000e18').toFixed(0), (await this.lic.balanceOf(deployer)).valueOf().toString());

		await time.increase(1);
		//unlock airdrop
		let balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseAdvisor({from: deployer});
		let balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(balBefore, balAfter);

		await time.increase(2 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseAdvisor({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(balBefore, balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseAdvisor({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(200000)).toFixed(0), balAfter);

		await time.increase(3 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseAdvisor({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(200000)).toFixed(0), balAfter);

		await time.increase(3 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseAdvisor({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(200000)).toFixed(0), balAfter);

		await time.increase(3 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseAdvisor({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(200000)).toFixed(0), balAfter);

		await time.increase(3 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseAdvisor({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(200000)).toFixed(0), balAfter);

		await time.increase(3 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseAdvisor({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(balBefore, balAfter);
	});

	it('Token unlock marketing', async () => {
		//total unlock at TGE = 1.2M + 2.5M + 6M = 9.7M
		assert.equal(new BN('9700000e18').toFixed(0), (await this.lic.balanceOf(deployer)).valueOf().toString());

		await time.increase(1);
		//unlock airdrop
		let balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseMarketing({from: deployer});
		let balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(balBefore, balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseMarketing({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(250000)).toFixed(0), balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseMarketing({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(250000)).toFixed(0), balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseMarketing({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(250000)).toFixed(0), balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseMarketing({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(250000)).toFixed(0), balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseMarketing({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(250000)).toFixed(0), balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseMarketing({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(new BN(balBefore).plus(toWei(250000)).toFixed(0), balAfter);

		await time.increase(1 * 86400 * 30);
		balBefore = (await this.lic.balanceOf(deployer)).valueOf().toString();
		await this.lic.releaseMarketing({from: deployer});
		balAfter = (await this.lic.balanceOf(deployer)).valueOf().toString();
		assert.equal(balBefore, balAfter);
	});
})