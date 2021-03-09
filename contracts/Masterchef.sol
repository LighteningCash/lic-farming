pragma solidity 0.6.12;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";





interface ILic is IERC20 {
	function pullRewards(uint256 _amount) external returns (uint256);
	function pullableRewards(uint256 _amount) external view returns (uint256);
}

//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once LIC is sufficiently
// distributed and the community can show to govern itself.
//
contract MasterChef is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
		uint256 lpLockedTil;	//LP token unlock time
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. LICs to distribute per block.
        uint256 accLicPerShare; // Accumulated LICs per share, times 1e12. See below.
        uint256 totalPaidReward;
		uint256 cumulativeRewardsSinceStart;	//deflationary rewards
        address referralToken;  //used for checking whether referrers can receive rewards
        uint256 minAmountForRef1;   //minimum referral token balance of referrer level 1
        uint256 minAmountForRef2;   //minimum referral token balance of referrer level 2
    }

	struct LockedReward {
		uint256 total;
		uint256 released;
	}

	uint256 public constant REWARD_LOCK_PERIOD = 180 days;
	uint256 public constant REWARD_LOCK_VESTING = 90 days;
	uint256 public constant REWARD_PAY_PERCENT_X10 = 235;

    uint256 public constant rewardPercentRef1 = 7;
    uint256 public constant rewardPercentRef2 = 3;

    uint256 public lastRewardBlock;  // Last block number that LIC distribution occurs.
    uint256 public ACC_TOTAL_REWARD;
    // The LIC TOKEN!
    ILic public lic;
    // Dev address.
    address public devaddr;
    // Block number when bonus LIC period ends.
    uint256 public bonus1EndBlock;
    uint256 public bonus2EndBlock;

    // LIC tokens created per block.
    uint256 public licPerBlock;
    // Bonus muliplier for early lic makers.
    //first 5 days: 5 LIC/s, 15LIC/block
    //next 5 days: 3 LIC/s, 9LIC.block
    //the rest: 1 LIC/s, 3LIC/block
    uint256 public constant BONUS1_MULTIPLIER = 5;
    uint256 public constant BONUS2_MULTIPLIER = 3;
    // The migrator contract. It has a lot of power. Can only be set through governance (owner).

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
	mapping(address => LockedReward) public lockedRewards;

    mapping(address => address) public referrers;

    //referrer => referrals
    mapping(address => address[]) public referredList;
    mapping(address => mapping(address => bool)) public referredCheckList;

    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when LIC mining starts.
    uint256 public startBlock;
	uint256 public startTimestamp;

	uint256 public oldLicBalance = 0;
	uint256 public rewardsFromFees = 0;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        ILic _lic,
        address _devaddr,
        uint256 _startBlock
    ) public {
        lic = _lic;
        devaddr = _devaddr;
        licPerBlock = 3e18;
        startBlock = block.number > _startBlock ? block.number : _startBlock;
        bonus1EndBlock = startBlock + 5 * 86400/3;  //5 days
        bonus2EndBlock = bonus1EndBlock + 5 * 86400/3;  //5 days
		startTimestamp = block.timestamp;
        lastRewardBlock = startBlock;
    }

    function poolLength() public view returns (uint256) {
        return poolInfo.length;
    }

	function addLicRewards() public {
		uint256 diff = lic.balanceOf(address(this)).sub(oldLicBalance);

        if (diff > 0) {
            oldLicBalance = lic.balanceOf(address(this)); 
            rewardsFromFees = rewardsFromFees.add(diff);
        }
	}

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IERC20 _lpToken, address _refToken, uint256 _minRef1, uint256 _minRef2, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            accLicPerShare: 0,
            totalPaidReward: ACC_TOTAL_REWARD,
			cumulativeRewardsSinceStart: 0,
            referralToken:_refToken,  //used for checking whether referrers can receive rewards
            minAmountForRef1: _minRef1,   //minimum referral token balance of referrer level 1
            minAmountForRef2: _minRef2   //minimum referral token balance of referrer level 2
        }));
    }

    // Update the given pool's LIC allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }


    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        if (_to <= bonus1EndBlock) {
            return _to.sub(_from).mul(BONUS1_MULTIPLIER);
        } else if (_to <= bonus2EndBlock) {
            if (_from >= bonus1EndBlock) {
                return _to.sub(_from).mul(BONUS2_MULTIPLIER);
            } else {
                return bonus1EndBlock.sub(_from).mul(BONUS1_MULTIPLIER).add(
                    _to.sub(bonus1EndBlock).mul(BONUS2_MULTIPLIER)
                );
            }
        } else if (_from >= bonus2EndBlock) {
            return _to.sub(_from);
        } else {
            return bonus2EndBlock.sub(_from).mul(BONUS2_MULTIPLIER).add(
                _to.sub(bonus2EndBlock)
            );
        }
    }

	function calculateRewardForAllPools(uint256 _from, uint256 _to) public view returns (uint256 inflation, uint256 fee) {
		uint256 multiplier = getMultiplier(_from, _to);
        inflation = multiplier.mul(licPerBlock);
        inflation = lic.pullableRewards(inflation);
        inflation = lic.pullableRewards(inflation);
		fee = rewardsFromFees;//dev reward included
	}

    // View function to see pending LIC on frontend.
    function pendingLic(uint256 _pid, address _user) public view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accLicPerShare = pool.accLicPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number >= lastRewardBlock && lpSupply != 0) {
			(uint256 inflation, ) = calculateRewardForAllPools(lastRewardBlock, block.number);
            uint256 totalReward = ACC_TOTAL_REWARD.add(inflation).add(rewardsFromFees);
            uint256 notCountedReward = totalReward.sub(pool.totalPaidReward);
            uint256 notCountedRewardForPool = notCountedReward.mul(pool.allocPoint).div(totalAllocPoint);
            uint256 licReward = notCountedRewardForPool.mul(85).div(100);
            accLicPerShare = accLicPerShare.add(licReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accLicPerShare).div(1e12).sub(user.rewardDebt);
    }

    function pendingLicAtNextBlock(uint256 _pid, address _user) public view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accLicPerShare = pool.accLicPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number >= lastRewardBlock && lpSupply != 0) {
			(uint256 inflation, ) = calculateRewardForAllPools(lastRewardBlock, block.number + 1);
            uint256 totalReward = ACC_TOTAL_REWARD.add(inflation).add(rewardsFromFees);
            uint256 notCountedReward = totalReward.sub(pool.totalPaidReward);
            uint256 notCountedRewardForPool = notCountedReward.mul(pool.allocPoint).div(totalAllocPoint);
            uint256 licReward = notCountedRewardForPool.mul(85).div(100);
            accLicPerShare = accLicPerShare.add(licReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accLicPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];

        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            return;
        }

        (uint256 inflation, ) = calculateRewardForAllPools(lastRewardBlock, block.number);
        inflation = lic.pullRewards(inflation);
        lastRewardBlock = block.number;
        ACC_TOTAL_REWARD = ACC_TOTAL_REWARD.add(inflation).add(rewardsFromFees);
        rewardsFromFees = 0;
        uint256 notCountedReward = ACC_TOTAL_REWARD.sub(pool.totalPaidReward);
        pool.totalPaidReward = ACC_TOTAL_REWARD;
        uint256 notCountedRewardForPool = notCountedReward.mul(pool.allocPoint).div(totalAllocPoint);

        uint256 licReward = notCountedRewardForPool.mul(85).div(100);
		uint256 devReward = notCountedRewardForPool.mul(5).div(100);
        //remaining 10% for referrals
        pool.accLicPerShare = pool.accLicPerShare.add(licReward.mul(1e12).div(lpSupply));

        lockRewardAndTransfer(devaddr, devReward);
    }

    // Deposit LP tokens to MasterChef for LIC allocation.
    function deposit(uint256 _pid, uint256 _amount, address _referrer) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accLicPerShare).div(1e12).sub(user.rewardDebt);
            lockRewardAndTransfer(msg.sender, pending);
            transferForReferrals(_pid, msg.sender, pending);
        }
        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accLicPerShare).div(1e12);

        if (referrers[address(msg.sender)] == address(0) && _referrer != address(0) && _referrer != address(msg.sender)) {
            referrers[address(msg.sender)] = address(_referrer);
            if (!referredCheckList[_referrer][msg.sender]) {
                referredList[_referrer].push(msg.sender);
                referredCheckList[_referrer][msg.sender] = true;
            }
        }
        emit Deposit(msg.sender, _pid, _amount);
    }

    function depositFor(uint256 _pid, address _toWhom, uint256 _amount, address _referrer) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_toWhom];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accLicPerShare).div(1e12).sub(user.rewardDebt);
            lockRewardAndTransfer(_toWhom, pending);
            transferForReferrals(_pid, _toWhom, pending);
        }
        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accLicPerShare).div(1e12);

        if (referrers[_toWhom] == address(0) && _referrer != address(0) && _referrer != _toWhom) {
            referrers[_toWhom] = address(_referrer);
            if (!referredCheckList[_referrer][_toWhom]) {
                referredList[_referrer].push(_toWhom);
                referredCheckList[_referrer][_toWhom] = true;
            }
        }
        emit Deposit(msg.sender, _pid, _amount);
    }

    function transferForReferrals(uint256 _pid, address _user, uint256 _mainPending) internal {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 totalForRefs = _mainPending.mul(10).div(85);    //refs = 10% of total rewards, user = 85% of total rewards
        uint256 totalPercent = rewardPercentRef1.add(rewardPercentRef2);
        uint256 referAmountLv1 = totalForRefs.mul(rewardPercentRef1).div(totalPercent);
        uint256 referAmountLv2 = totalForRefs.mul(rewardPercentRef2).div(totalPercent);
        address refTokenAddress = pool.referralToken != address(0) ? pool.referralToken: address(lic);
        IERC20 refToken = IERC20(refTokenAddress);
        uint256 referralsToDev = 0;
        address ref1Address = referrers[_user];
        address ref2Address = referrers[ref1Address];
        if (ref1Address != address(0)) {
            if (refToken.balanceOf(ref1Address) >= pool.minAmountForRef1) {
                safeLicTransfer(ref1Address, referAmountLv1);
            } else {
                referralsToDev = referralsToDev.add(referAmountLv1);
            }
            if (ref2Address != address(0)) {
                if (refToken.balanceOf(ref2Address) >= pool.minAmountForRef2) {
                    safeLicTransfer(ref2Address, referAmountLv2);
                } else {
                    referralsToDev = referralsToDev.add(referAmountLv2);
                }
            } else {
                referralsToDev = referralsToDev.add(referAmountLv2);           
            }
        } else {
            referralsToDev = referAmountLv1.add(referAmountLv2);
        }
        if (referralsToDev > 0) {
            lockRewardAndTransfer(devaddr, referralsToDev);
        }
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accLicPerShare).div(1e12).sub(user.rewardDebt);
        lockRewardAndTransfer(msg.sender, pending);
        transferForReferrals(_pid, msg.sender, pending);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accLicPerShare).div(1e12);
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    function releasableLockedReward(address _addr) public view returns (uint256) {
        if (startTimestamp.add(REWARD_LOCK_PERIOD) >= block.timestamp) return 0;
        uint256 timePassed = block.timestamp.sub(startTimestamp.add(REWARD_LOCK_PERIOD));
		uint256 totalReleasable = lockedRewards[_addr].total.mul(timePassed).div(REWARD_LOCK_PERIOD);
		totalReleasable = totalReleasable < lockedRewards[_addr].total ? totalReleasable:lockedRewards[_addr].total;
		uint256 shouldRelease =  totalReleasable.sub(lockedRewards[_addr].released);
        return shouldRelease;
    }

	function releaseLockedReward(address _addr) public {
		require(startTimestamp.add(REWARD_LOCK_PERIOD) < block.timestamp, "!lock period");
		uint256 timePassed = block.timestamp.sub(startTimestamp.add(REWARD_LOCK_PERIOD));
		uint256 totalReleasable = lockedRewards[_addr].total.mul(timePassed).div(REWARD_LOCK_PERIOD);
		totalReleasable = totalReleasable < lockedRewards[_addr].total ? totalReleasable:lockedRewards[_addr].total;
		uint256 shouldRelease =  totalReleasable.sub(lockedRewards[_addr].released);
		lockedRewards[_addr].total = totalReleasable;
		safeLicTransfer(_addr, shouldRelease);
	}

	function lockRewardAndTransfer(address _to, uint256 _amount) internal {
		uint256 shouldPay = _amount.mul(REWARD_PAY_PERCENT_X10).div(1000);
        if (startTimestamp.add(REWARD_LOCK_PERIOD) < block.timestamp) {
            //lock period pass
            shouldPay = _amount;
        }
		safeLicTransfer(_to, shouldPay);
		uint256 shouldLock = _amount.sub(shouldPay);
		lockedRewards[_to].total = lockedRewards[_to].total.add(shouldLock);
	}

    // Safe lic transfer function, just in case if rounding error causes pool to not have enough LICs.
    function safeLicTransfer(address _to, uint256 _amount) internal {
        uint256 licBal = lic.balanceOf(address(this));
        if (_amount > licBal) {
            lic.transfer(_to, licBal);
        } else {
            lic.transfer(_to, _amount);
        }
		oldLicBalance = lic.balanceOf(address(this)); 
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }

    function getReferredList(address _referrer) public view returns (address[] memory) {
        return referredList[_referrer];
    }

    function getReferers(address _user) public view returns (address ref1, address ref2) {
        ref1 = referrers[_user];
        ref2 = referrers[ref1];
    }

    function getPendingReferralReward(address _referrer) public view returns (uint256) {
        uint256 ret = 0;
        uint256 totalRewardsOfLv1 = 0;
        uint256 totalRewardsOfLv2 = 0;
        address[] memory refsLv1 = referredList[_referrer];
        uint256 numPool = poolLength();
        for(uint256 i = 0; i < refsLv1.length; i++) {
            for(uint256 j = 0; j < numPool; j++) {
                totalRewardsOfLv1 = totalRewardsOfLv1.add(pendingLic(j, refsLv1[i]));
            }
        }

        for(uint256 i = 0; i < refsLv1.length; i++) {
            address[] memory refsOfRefs = referredList[refsLv1[i]];
            for(uint256 j = 0; j < refsOfRefs.length; j++) {
                for(uint256 k = 0; k < numPool; k++) {
                    totalRewardsOfLv2 = totalRewardsOfLv2.add(pendingLic(k, refsOfRefs[j]));
                }
            }
        }

        ret = ret.add(totalRewardsOfLv1.mul(10).div(85).mul(7).div(10));
        ret = ret.add(totalRewardsOfLv2.mul(10).div(85).mul(3).div(10));
        return ret;
    }
}