pragma solidity 0.6.12;
interface IMasterchefDeposit {
    function depositFor(uint256 _pid, address _toWhom, uint256 _amount, address _referrer)  external;
}