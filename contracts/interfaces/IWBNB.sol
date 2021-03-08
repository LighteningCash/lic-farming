pragma solidity 0.6.12;
interface IWBNB {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
	function approve(address spender, uint value) external returns (bool);
	function balanceOf(address account) external view returns (uint256);
}