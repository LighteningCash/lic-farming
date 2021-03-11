const { expectRevert, time } = require('@openzeppelin/test-helpers');
const BN = require('bignumber.js');
BN.config({ DECIMAL_PLACES: 0 })
BN.config({ ROUNDING_MODE: BN.ROUND_DOWN })
const Lic = artifacts.require('Lic');
const Masterchef = artifacts.require('Masterchef');
const MockERC20 = artifacts.require('MockERC20');
const TimeLock = artifacts.require('TimeLock');

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

contract('MasterChef', (allAccounts) => {
	deployer = allAccounts[0];
	accounts = allAccounts.slice(1);
	let ref0 = allAccounts[200];
	let ref1 = allAccounts[201];
    beforeEach(async () => {
        this.lic = await Lic.new(deployer, {from: deployer});
		this.masterchef = await Masterchef.new(this.lic.address, deployer, 0, {from: deployer});
    });

	it('1 LP', async () => {
		this.lp = await MockERC20.new(deployer, {from: deployer});
		await this.masterchef.add(1000, this.lp.address, this.lp.address, 0, 0, false);
		await this.lic.setFarmingMasterChef(this.masterchef.address, {from: deployer});
		await assert.equal('1', (await this.masterchef.poolLength()).valueOf().toString());
		await this.lp.transfer(accounts[0], '100', {from: deployer});
		await assert.equal('0', (await this.masterchef.pendingLic(0, accounts[0])).valueOf().toString());
		await this.lp.approve(this.masterchef.address, new BN('100000e18'), {from: accounts[0]});
		await this.masterchef.deposit(0, '100', ref0, {from: accounts[0]});
		const startBlock = (await this.masterchef.startBlock()).valueOf().toString();
		const currentBlock = await time.latestBlock();
		const numBlock = new BN(currentBlock).minus(startBlock).toFixed(0);
		const totalPendingRewards = new BN(numBlock).multipliedBy(5*3).multipliedBy(new BN('1e18'));

		const pendingReward0 = (await this.masterchef.pendingLic(0, accounts[0])).valueOf().toString();
		assert.equal(pendingReward0, totalPendingRewards.multipliedBy(85).dividedBy(100).toFixed(0));
		const ref0Reward = (await this.masterchef.getPendingReferralReward(ref0)).valueOf().toString();
		const expectedRef0 = new BN(pendingReward0).multipliedBy(10).dividedBy(85).multipliedBy(7).dividedBy(10).toFixed(0);
		assert.equal(ref0Reward, expectedRef0);

		await assertHarvest(this, accounts[0], 0);
		await assertHarvest(this, accounts[0], 0);
	});

	it('Token Lock', async () => {

	});

	it('Many LPs', async () => {
		this.lps = [];
		const numAcc = 20;
		const numLP = 2;
		await this.lic.setFarmingMasterChef(this.masterchef.address, {from: deployer});
		for(var i = 0; i < numLP; i++) {
			this.lps.push(await MockERC20.new(deployer, {from: deployer}));
			await this.masterchef.add(1000, this.lps[i].address, this.lps[i].address, 0, 0, false);
			await this.lps[i].transfer(ref0, '100', {from: deployer});
		}
		await assert.equal(numLP.toString(), (await this.masterchef.poolLength()).valueOf().toString());

		for(var i = 0; i < numLP; i++) {
			for(var j = 0; j < numAcc; j++) {
				await this.lps[i].transfer(accounts[j], '100', {from: deployer});
				await assert.equal('0', (await this.masterchef.pendingLic(i, accounts[j])).valueOf().toString());
				await this.lps[i].approve(this.masterchef.address, new BN('100000e18'), {from: accounts[j]});
				await this.masterchef.deposit(i, '100', ref0, {from: accounts[j]});
			}
			await this.lps[i].approve(this.masterchef.address, new BN('100000e18'), {from: ref0});
			await this.masterchef.deposit(i, '100', ref1, {from: ref0});
		}
		

		let totalRewardsWithdrawn = 0;
		let toalRefRewardReceived = 0;
		let toalRef1RewardReceived = 0;
		const refBalBefore = (await this.lic.balanceOf(ref0)).valueOf().toString();
		const ref1Before = (await this.lic.balanceOf(ref1)).valueOf().toString();
		for(var i = 0; i < numLP; i++) {
			for(var j = 0; j < numAcc; j++) {
				let withdrawn = await assertHarvestPending(this, accounts[j], i);
				totalRewardsWithdrawn = new BN(withdrawn).plus(totalRewardsWithdrawn).toFixed(0);

				const refReward = new BN(withdrawn).multipliedBy(10).dividedBy(85);
				const ref0Reward = refReward.multipliedBy(7).dividedBy(10).toFixed(0);
				const ref1Reward = refReward.multipliedBy(3).dividedBy(10).toFixed(0);
				toalRefRewardReceived = new BN(toalRefRewardReceived).plus(ref0Reward).toFixed(0);
				toalRef1RewardReceived = new BN(toalRef1RewardReceived).plus(ref1Reward).toFixed(0);
			}
		}
		const refBalAfter = (await this.lic.balanceOf(ref0)).valueOf().toString();
		const ref1After = (await this.lic.balanceOf(ref1)).valueOf().toString();
		assert.equal(toalRefRewardReceived, new BN(refBalAfter).minus(refBalBefore).toFixed(0));
		assert.equal(toalRef1RewardReceived, new BN(ref1After).minus(ref1Before).toFixed(0));

		for(var i = 0; i < numLP; i++) {
			for(var j = 0; j < numAcc; j++) {
				await this.masterchef.withdraw(i, 100, {from: accounts[j]});
			}
		}

	});

	it('Many LPs with fees', async () => {
		this.lps = [];
		const numAcc = 20;
		const numLP = 2;
		await this.lic.setFarmingMasterChef(this.masterchef.address, {from: deployer});
		await this.lic.setWhitelist(this.lic.address, {from: deployer}); 
		await this.lic.setWhitelist(this.masterchef.address, {from: deployer}); 
		await this.lic.setFeePerThousand(10, {from: deployer}); 
		for(var i = 0; i < numLP; i++) {
			this.lps.push(await MockERC20.new(deployer, {from: deployer}));
			await this.masterchef.add(1000, this.lps[i].address, this.lps[i].address, 0, 0, false);
			await this.lps[i].transfer(ref0, '100', {from: deployer});
		}
		await assert.equal(numLP.toString(), (await this.masterchef.poolLength()).valueOf().toString());

		for(var i = 0; i < numLP; i++) {
			for(var j = 0; j < numAcc; j++) {
				await this.lps[i].transfer(accounts[j], '100', {from: deployer});
				await assert.equal('0', (await this.masterchef.pendingLic(i, accounts[j])).valueOf().toString());
				await this.lps[i].approve(this.masterchef.address, new BN('100000e18'), {from: accounts[j]});
				await this.masterchef.deposit(i, '100', ref0, {from: accounts[j]});
			}
			await this.lps[i].approve(this.masterchef.address, new BN('100000e18'), {from: ref0});
			await this.masterchef.deposit(i, '100', ref1, {from: ref0});
		}
		

		let totalRewardsWithdrawn = 0;
		let toalRefRewardReceived = 0;
		let toalRef1RewardReceived = 0;
		const refBalBefore = (await this.lic.balanceOf(ref0)).valueOf().toString();
		const ref1Before = (await this.lic.balanceOf(ref1)).valueOf().toString();
		for(var i = 0; i < numLP; i++) {
			for(var j = 0; j < numAcc; j++) {
				let withdrawn = await assertHarvestPending(this, accounts[j], i);
				totalRewardsWithdrawn = new BN(withdrawn).plus(totalRewardsWithdrawn).toFixed(0);

				const refReward = new BN(withdrawn).multipliedBy(10).dividedBy(85);
				const ref0Reward = refReward.multipliedBy(7).dividedBy(10).toFixed(0);
				const ref1Reward = refReward.multipliedBy(3).dividedBy(10).toFixed(0);
				toalRefRewardReceived = new BN(toalRefRewardReceived).plus(ref0Reward).toFixed(0);
				toalRef1RewardReceived = new BN(toalRef1RewardReceived).plus(ref1Reward).toFixed(0);
			}
		}
		const refBalAfter = (await this.lic.balanceOf(ref0)).valueOf().toString();
		const ref1After = (await this.lic.balanceOf(ref1)).valueOf().toString();
		assert.equal(toalRefRewardReceived, new BN(refBalAfter).minus(refBalBefore).toFixed(0));
		assert.equal(toalRef1RewardReceived, new BN(ref1After).minus(ref1Before).toFixed(0));

		for(var i = 0; i < numLP; i++) {
			for(var j = 0; j < numAcc; j++) {
				await this.masterchef.withdraw(i, 100, {from: accounts[j]});
			}
		}
	});

	it('Many LPs with fees 2', async () => {
		this.lps = [];
		const numAcc = 20;
		const sender = accounts[30];
		const numLP = 2;
		await this.lic.setFarmingMasterChef(this.masterchef.address, {from: deployer});
		await this.lic.setWhitelist(this.lic.address, true, {from: deployer}); 
		await this.lic.setWhitelist(this.masterchef.address, true, {from: deployer}); 
		await this.lic.setFeePerThousand(10, {from: deployer}); 

		await this.lic.transfer(sender, new BN('10000e18').toFixed(), {from: deployer})

		for(var i = 0; i < numLP; i++) {
			this.lps.push(await MockERC20.new(deployer, {from: deployer}));
			await this.masterchef.add(1000, this.lps[i].address, this.lps[i].address, 0, 0, false);
			await this.lps[i].transfer(ref0, '100', {from: deployer});
		}
		await assert.equal(numLP.toString(), (await this.masterchef.poolLength()).valueOf().toString());

		for(var i = 0; i < numLP; i++) {
			for(var j = 0; j < numAcc; j++) {
				await this.lps[i].transfer(accounts[j], '100', {from: deployer});
				await assert.equal('0', (await this.masterchef.pendingLic(i, accounts[j])).valueOf().toString());
				await this.lps[i].approve(this.masterchef.address, new BN('100000e18'), {from: accounts[j]});
				await this.masterchef.deposit(i, '100', ref0, {from: accounts[j]});
			}
			await this.lps[i].approve(this.masterchef.address, new BN('100000e18'), {from: ref0});
			await this.masterchef.deposit(i, '100', ref1, {from: ref0});
		}
		

		let totalRewardsWithdrawn = 0;
		let toalRefRewardReceived = 0;
		let toalRef1RewardReceived = 0;
		const refBalBefore = (await this.lic.balanceOf(ref0)).valueOf().toString();
		const ref1Before = (await this.lic.balanceOf(ref1)).valueOf().toString();
		for(var i = 0; i < numLP; i++) {
			for(var j = 0; j < numAcc; j++) {
				assert.equal('0', (await this.masterchef.rewardsFromFees()).valueOf().toString());
				let fees = (await this.lic.computeTxFee(sender, sender, new BN('100e18').toFixed(0))).valueOf();
				assert.notEqual('0', fees[0].toString());
				await this.lic.transfer(sender, new BN('100e18').toFixed(0), {from: sender})
				assert.notEqual('0', (await this.masterchef.rewardsFromFees()).valueOf().toString());
				let withdrawn = await assertHarvestPendingNoAssert(this, accounts[j], i);
				totalRewardsWithdrawn = new BN(withdrawn).plus(totalRewardsWithdrawn).toFixed(0);

				const refReward = new BN(withdrawn).multipliedBy(10).dividedBy(85);
				const ref0Reward = refReward.multipliedBy(7).dividedBy(10).toFixed(0);
				const ref1Reward = refReward.multipliedBy(3).dividedBy(10).toFixed(0);
				toalRefRewardReceived = new BN(toalRefRewardReceived).plus(ref0Reward).toFixed(0);
				toalRef1RewardReceived = new BN(toalRef1RewardReceived).plus(ref1Reward).toFixed(0);
			}
		}
		const refBalAfter = (await this.lic.balanceOf(ref0)).valueOf().toString();
		const ref1After = (await this.lic.balanceOf(ref1)).valueOf().toString();
		assert.equal(toalRefRewardReceived, new BN(refBalAfter).minus(refBalBefore).toFixed(0));
		assert.equal(toalRef1RewardReceived, new BN(ref1After).minus(ref1Before).toFixed(0));

		for(var i = 0; i < numLP; i++) {
			for(var j = 0; j < numAcc; j++) {
				await this.masterchef.withdraw(i, 100, {from: accounts[j]});
			}
		}
	});

	it('Time Lock', async () => {
		this.timelock = await TimeLock.new(deployer, 86400, {from: deployer});
		await this.lic.transferOwnership(this.timelock.address, {from: deployer});
		let callData = await this.lic.abi.encodeWithSelectorsetWhitelist(this.timelock.address, true).encode
	});
})