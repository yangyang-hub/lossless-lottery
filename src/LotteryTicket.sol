// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract LotteryTicket is ERC20, Ownable {
    address public lotteryHook;
    
    modifier onlyLottery() {
        require(msg.sender == lotteryHook, "Only lottery hook can mint/burn");
        _;
    }
    
    constructor() ERC20("Lottery Ticket", "LTKT") Ownable(msg.sender) {}
    
    function setLotteryHook(address _lotteryHook) external onlyOwner {
        lotteryHook = _lotteryHook;
    }
    
    function mint(address to, uint256 amount) external onlyLottery {
        _mint(to, amount);
    }
    
    function burn(address from, uint256 amount) external onlyLottery {
        _burn(from, amount);
    }
}