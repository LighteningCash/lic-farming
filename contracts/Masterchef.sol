pragma solidity 0.6.12;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";




interface IMigratorChef {
    function migrate(IERC20 token) external returns (IERC20);
}
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
        uint256 lastRewardBlock;  // Last block number that LIC distribution occurs.
        uint256 accLicPerShare; // Accumulated LICs per share, times 1e12. See below.
		bool emergencyWithdrawable;
		uint256 cumulativeRewardsSinceStart;	//deflationary rewards
    }

	struct LockedReward {
		uint256 total;
		uint256 released;
	}

	uint256 public constant REWARD_LOCK_PERIOD = 180 days;
	uint256 public constant REWARD_LOCK_VESTING = 90 days;
	uint256 public constant REWARD_LOCK_PERCENT = 75;

    // The LIC TOKEN!
    ILic public lic;
    // Dev address.
    address public devaddr;
    // Block number when bonus LIC period ends.
    uint256 public bonusEndBlock;
    // LIC tokens created per block.
    uint256 public licPerBlock;
    // Bonus muliplier for early lic makers.
    uint256 public constant BONUS_MULTIPLIER = 5;
    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorChef public migrator;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
	mapping(address => LockedReward) public lockedRewards;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when LIC mining starts.
    uint256 public startBlock;
	uint256 public startTimestamp;

	uint256 public oldLicBalance = 0;
	uint256 public rewardsFromFees = 0;
	uint256 public pendingDevRewards = 0;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        ILic _lic,
        address _devaddr,
        uint256 _licPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock
    ) public {
        lic = _lic;
        devaddr = _devaddr;
        licPerBlock = _licPerBlock;
        bonusEndBlock = _bonusEndBlock;
        startBlock = _startBlock;
		startTimestamp = block.timestamp;
    }

    function poolLength() external view returns (uint256) {
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
    function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accLicPerShare: 0,
			emergencyWithdrawable: false, 
			cumulativeRewardsSinceStart: 0
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

    // Set the migrator contract. Can only be called by the owner.
    function setMigrator(IMigratorChef _migrator) public onlyOwner {
        migrator = _migrator;
    }

    // Migrate lp token to another lp contract. Can be called by anyone. We trust that migrator contract is good.
    function migrate(uint256 _pid) public {
        require(address(migrator) != address(0), "migrate: no migrator");
        PoolInfo storage pool = poolInfo[_pid];
        IERC20 lpToken = pool.lpToken;
        uint256 bal = lpToken.balanceOf(address(this));
        lpToken.safeApprove(address(migrator), bal);
        IERC20 newLpToken = migrator.migrate(lpToken);
        require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
        pool.lpToken = newLpToken;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        } else if (_from >= bonusEndBlock) {
            return _to.sub(_from);
        } else {
            return bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER).add(
                _to.sub(bonusEndBlock)
            );
        }
    }

	function calculateTotalRewardForPool(uint256 _pid, uint256 _from, uint256 _to) public view returns (uint256 inflation, uint256 fee) {
		PoolInfo storage pool = poolInfo[_pid];
		uint256 multiplier = getMultiplier(_from, _to);
        inflation = multiplier.mul(licPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
		inflation = inflation.mul(11).div(10);	//dev reward included
        inflation = lic.pullableRewards(inflation);
		fee = rewardsFromFees.mul(pool.allocPoint).div(totalAllocPoint);//dev reward included
	}

    // View function to see pending LIC on frontend.
    function pendingLic(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accLicPerShare = pool.accLicPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
			(uint256 inflation, uint256 fee) = calculateTotalRewardForPool(_pid, pool.lastRewardBlock, block.number);
			uint256 licReward = (inflation.add(fee)).mul(10).div(11);
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
		rewardsFromFees = 0;
		safeLicTransfer(devaddr, pendingDevRewards);
		pendingDevRewards = 0;
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
		(uint256 inflation, uint256 fee) = calculateTotalRewardForPool(_pid, pool.lastRewardBlock, block.number);
        uint256 totalReward = inflation.add(fee);
        uint256 licReward = totalReward.mul(10).div(11);
		uint256 devReward = totalReward.div(11);

		pendingDevRewards = pendingDevRewards.add(devReward);

        pool.accLicPerShare = pool.accLicPerShare.add(licReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for LIC allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        massUpdatePools();
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accLicPerShare).div(1e12).sub(user.rewardDebt);
            safeLicTransfer(msg.sender, pending);
        }
        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accLicPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        massUpdatePools();
        uint256 pending = user.amount.mul(pool.accLicPerShare).div(1e12).sub(user.rewardDebt);
        safeLicTransfer(msg.sender, pending);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accLicPerShare).div(1e12);
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
		require(pool.emergencyWithdrawable, "!emergencyWithdrawable");
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
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
		uint256 shouldPay = _amount.mul(REWARD_LOCK_PERCENT).div(100);
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
}