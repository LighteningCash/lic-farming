pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // for WETH
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Airdrop is Ownable {
    address [] public whitelist;
    address [] public claimed;
    mapping (address => bool) public claimerWhitelist;
    mapping (address => bool) public claimerClaimed;
    mapping (address => uint256) public claimerBalances;

    uint256 public startBlock;
    uint256 public endBlock;
	bool public isInitialized = false;

    event Claim(address token, address holder, uint256 amount);

    function initialize(uint256 start, uint256 end) public onlyOwner {
		require(!isInitialized, "already initialize");
        startBlock = start;
        endBlock = end;
		isInitialized = true;
    }


    function newAddress(address guy, uint256 amount) public onlyOwner {
        whitelist.push(guy);
        claimerWhitelist[guy] = true;
        claimerBalances[guy] = amount;
    }

    function newAddress(address[] memory guys, uint256[] memory amount) public onlyOwner {
        for (uint i = 0; i < guys.length; i++) {
            whitelist.push(guys[i]);
            claimerWhitelist[guys[i]] = true;
            claimerBalances[guys[i]] = amount[i];
        }
    }

    function newAddress(address[] memory guys, uint256 amount) public onlyOwner {
        for (uint i = 0; i < guys.length; i++) {
            whitelist.push(guys[i]);
            claimerWhitelist[guys[i]] = true;
            claimerBalances[guys[i]] = amount;
        }
    }

    function claimToken(address token) public {
        require(claimerClaimed[msg.sender] == false);
        require(claimerWhitelist[msg.sender]);
        require(block.number >= startBlock);
        require(block.number <= endBlock);
        require(IERC20(token).balanceOf(address(this)) >= getBalanceCanClain(msg.sender));
        uint256 amount = getBalanceCanClain(msg.sender);
        IERC20(token).transfer(msg.sender, amount);
        claimerClaimed[msg.sender] = true;
        claimed.push(msg.sender);
        emit Claim(token, msg.sender, amount);
    }

    function getBalanceCanClain(address guy) public view returns (uint256){
        if (!claimerWhitelist[guy]) {
            return 0;
        }
        if (claimerClaimed[guy]) {
            return 0;
        }
        if (block.number < startBlock || block.number > endBlock) {
            return 0;
        }
        return claimerBalances[guy];
    }

    function withdrawAll(address token) onlyOwner public {
        require(block.number > endBlock);
        IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }

    function withdraw(address token, uint256 amount) onlyOwner public {
        require(block.number > endBlock);
        IERC20(token).transfer(msg.sender, amount);
    }
}