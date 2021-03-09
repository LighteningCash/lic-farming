pragma solidity 0.6.12;

interface IPancakeFactorySimplified {
	function getPair(address _t0, address _t1) external view returns (address);
}