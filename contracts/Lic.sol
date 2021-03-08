// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // for WETH
import "./BaseERC20.sol"; // for WETH
import "@openzeppelin/contracts/access/Ownable.sol";

interface IMasterchef {
    function addLicRewards() external;
}

//token owner will be a time lock contract after farming started
contract Lic is Context, Ownable, BaseERC20 {
    using SafeMath for uint256;
    using Address for address;

    struct LockedToken {
        bool isUnlocked;
        uint256 unlockedTime;
        uint256 amount;
    }

    uint256 public constant MAX_SUPPLY = 50000000e18;

    uint256 public constant AIRDROP = 6000000e18; //12%
    uint256 public constant LIQUIDITY = 2500000e18;
    uint256 public constant TEAM = 3000000e18;
    uint256 public constant MARKETING = 7500000e18;
    uint256 public constant DEVELOPMENT = 5000000e18;
    uint256 public constant FARMING_TOTAL = 17500000e18;
    uint256 public constant ADVISOR = 1000000e18;
    uint256 public constant ECOSYSTEM = 7500000e18;

    address public masterchef;

    uint256 public initTime;

    address public tokenRecipient;
    uint256 public currentPaidRewards = 0;

    uint256 public airdropUnlocked = 0;
    uint256 public teamUnlocked = 0;
    uint256 public developmentUnlocked = 0;
    uint256 public ecosystemUnlocked = 0;
    uint256 public advisorUnlocked = 0;
    uint256 public marketingUnlocked = 0;

    constructor(address _dev) public BaseERC20("LIGHTENING.CASH", "LIC") {
        initialSetup(_dev);
    }

    function initialSetup(address _dev) internal {
        initTime = block.timestamp;
        tokenRecipient = _dev;

        uint256 totalUnlocked = 0;
        airdropUnlocked = AIRDROP.mul(20).div(100);
        marketingUnlocked = MARKETING.mul(80).div(100);

        totalUnlocked = totalUnlocked.add(airdropUnlocked);
        totalUnlocked = totalUnlocked.add(LIQUIDITY);
        totalUnlocked = totalUnlocked.add(marketingUnlocked);

        whitelist[address(this)] = true;
        whitelist[tokenRecipient] = true;
        _mint(address(this), MAX_SUPPLY);
        _transfer(address(this), tokenRecipient, totalUnlocked);
    }

    function releasableAirdrop() public view returns (uint256) {
        if (initTime == 0) return 0;
        uint256 startReleasing = initTime.add(6 * 30 * 86400);
        if (startReleasing > block.timestamp) return 0;
        uint256 gap = block.timestamp.sub(startReleasing);
        uint256 months = gap.div(30 * 86400) + 1;
        uint256 totalReleasable = AIRDROP.mul(20).div(100) +
            months.mul(AIRDROP.mul(10).div(100));
        if (totalReleasable > AIRDROP) {
            totalReleasable = AIRDROP;
        }
        return totalReleasable.sub(airdropUnlocked);
    }

    function releasableTeam() public view returns (uint256) {
        if (initTime == 0) return 0;
        uint256 startReleasing = initTime.add(12 * 30 * 86400);
        if (startReleasing > block.timestamp) return 0;
        uint256 gap = block.timestamp.sub(startReleasing);
        uint256 months = gap.div(30 * 86400) + 1;
        uint256 totalReleasable = months.mul(TEAM.mul(10).div(100));
        if (totalReleasable > TEAM) {
            totalReleasable = TEAM;
        }
        return totalReleasable.sub(teamUnlocked);
    }

    function releasableMarketing() public view returns (uint256) {
        if (initTime == 0) return 0;
        uint256 startReleasing = initTime.add(1 * 30 * 86400);
        if (startReleasing > block.timestamp) return 0;
        uint256 gap = block.timestamp.sub(startReleasing);
        uint256 months = gap.div(30 * 86400) +  1;
        uint256 totalReleasable = MARKETING.mul(80).div(100) +
            months.mul(MARKETING.mul(35).div(1000));    //3.5%/month
        if (totalReleasable > MARKETING) {
            totalReleasable = MARKETING;
        }
        return totalReleasable.sub(marketingUnlocked);
    }


    function releasableDevelopment() public view returns (uint256) {
        if (initTime == 0) return 0;
        uint256 startReleasing = initTime.add(6 * 30 * 86400);
        if (startReleasing > block.timestamp) return 0;
        uint256 gap = block.timestamp.sub(startReleasing);
        uint256 months = gap.div(30 * 86400) + 1;
        uint256 totalReleasable = months.mul(DEVELOPMENT.mul(10).div(100));
        if (totalReleasable > DEVELOPMENT) {
            totalReleasable = DEVELOPMENT;
        }
        return totalReleasable.sub(developmentUnlocked);
    }

    function releasableEcosystem() public view returns (uint256) {
        if (initTime == 0) return 0;
        uint256 startReleasing = initTime.add(6 * 30 * 86400);
        if (startReleasing > block.timestamp) return 0;
        uint256 totalReleasable = ECOSYSTEM;
        return totalReleasable.sub(ecosystemUnlocked);
    }

    function releasableAdvisor() public view returns (uint256) {
        if (initTime == 0) return 0;
        uint256 startReleasing = initTime.add(3 * 30 * 86400);
        if (startReleasing > block.timestamp) return 0;
        uint256 gap = block.timestamp.sub(startReleasing);
        uint256 months = gap.div(3 * 30 * 86400) + 1;
        uint256 totalReleasable = months.mul(ADVISOR.mul(20).div(100));
        if (totalReleasable > ADVISOR) {
            totalReleasable = ADVISOR;
        }
        return totalReleasable.sub(advisorUnlocked);
    }

    function releaseAirdrop() public {
        uint256 releasable = releasableAirdrop();
        if (releasable > 0) {
            airdropUnlocked = airdropUnlocked.add(releasable);
            _transfer(address(this), tokenRecipient, releasable);
        }
    }

    function releaseTeam() public {
        uint256 releasable = releasableTeam();
        if (releasable > 0) {
            teamUnlocked = teamUnlocked.add(releasable);
            _transfer(address(this), tokenRecipient, releasable);
        }
    }

    function releaseDevelopment() public {
        uint256 releasable = releasableDevelopment();
        if (releasable > 0) {
            developmentUnlocked = developmentUnlocked.add(releasable);
            _transfer(address(this), tokenRecipient, releasable);
        }
    }

    function releaseEcosystem() public {
        uint256 releasable = releasableEcosystem();
        if (releasable > 0) {
            ecosystemUnlocked = ecosystemUnlocked.add(releasable);
            _transfer(address(this), tokenRecipient, releasable);
        }
    }

    function releaseAdvisor() public {
        uint256 releasable = releasableAdvisor();
        if (releasable > 0) {
            advisorUnlocked = advisorUnlocked.add(releasable);
            _transfer(address(this), tokenRecipient, releasable);
        }
    }

    function releaseMarketing() public {
        uint256 releasable = releasableMarketing();
        if (releasable > 0) {
            marketingUnlocked = marketingUnlocked.add(releasable);
            _transfer(address(this), tokenRecipient, releasable);
        }
    }

    function setTokenReceiver(address _tr) public onlyOwner {
        tokenRecipient = _tr;
    }

    function setFarmingMasterChef(address _m) public onlyOwner {
        masterchef = _m;
    }

    function pullRewards(uint256 _amount) public returns (uint256) {
        require(msg.sender == masterchef, "!vault");
        if (_amount >= FARMING_TOTAL) return 0;
        uint256 _transferAmount = _amount;
        if (currentPaidRewards.add(_transferAmount) > FARMING_TOTAL) {
            _transferAmount = FARMING_TOTAL.sub(currentPaidRewards);
        }
        currentPaidRewards = currentPaidRewards.add(_transferAmount);
        _transfer(address(this), masterchef, _transferAmount);
		return _transferAmount;
    }

	function pullableRewards(uint256 _amount) public view returns (uint256) {
		if (_amount >= FARMING_TOTAL) return 0;
        uint256 _transferAmount = _amount;
        if (currentPaidRewards.add(_transferAmount) > FARMING_TOTAL) {
            _transferAmount = FARMING_TOTAL.sub(currentPaidRewards);
        }
		return _transferAmount;
	}

    uint256 public txFeePerThousand = 0;    
    function setFeePerThousand(uint256 _fee) public onlyOwner {
        require(_fee <= 10, "max fee is 1%");
        txFeePerThousand = _fee;
    }
    mapping (address => bool) whitelist;    //reserved for token contract, masterchef, pancake pair
    mapping (address => bool) whitelistRecipient;    //reserved for token contract, masterchef, pancake pair
    function setWhitelist(address _addr, bool _val) public onlyOwner {
        whitelist[_addr] = _val;
    }

    function setWhitelistRecipient(address _addr, bool _val) public onlyOwner {
        whitelistRecipient[_addr] = _val;
    }

	function _transfer(address sender, address recipient, uint256 amount) internal override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");

        uint256 fee = 0;
        uint256 recipientAmount = amount;
        if (!whitelist[sender] && !whitelistRecipient[recipient] && txFeePerThousand > 0 && masterchef != address(0)) {
            fee = amount.mul(txFeePerThousand).div(1000);
            recipientAmount = amount.sub(fee);
        }
        require(fee.add(recipientAmount) == amount, "!!!! Fee calculation");

        _balances[recipient] = _balances[recipient].add(recipientAmount);
        emit Transfer(sender, recipient, recipientAmount);

        if (fee > 0) {
            _balances[masterchef] = _balances[masterchef].add(fee);
            emit Transfer(sender, recipient, fee);
            IMasterchef(masterchef).addLicRewards();
        }
	}
}
