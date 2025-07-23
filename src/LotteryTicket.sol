// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title LotteryTicket - 彩票代币合约
 * @dev 这是彩票系统的ERC20代币合约，用于代表彩票参与资格
 * @dev 代币只能由彩票钩子合约铸造和销毁
 * @author 基于OpenZeppelin ERC20实现
 */

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract LotteryTicket is ERC20, Ownable {
    /// @notice 彩票钩子合约地址，拥有铸币和销毁权限
    address public lotteryHook;
    
    /// @notice 修饰符：确保只有彩票钩子合约可以调用
    modifier onlyLottery() {
        require(msg.sender == lotteryHook, "Only lottery hook can mint/burn");
        _;
    }
    
    /**
     * @notice 构造函数，初始化彩票代币
     * @dev 设置代币名称为"Lottery Ticket"，符号为"LTKT"
     * @dev 将合约部署者设置为所有者
     */
    constructor() ERC20("Lottery Ticket", "LTKT") Ownable(msg.sender) {}
    
    /**
     * @notice 设置彩票钩子合约地址
     * @dev 只有合约所有者可以调用此函数
     * @param _lotteryHook 彩票钩子合约地址
     */
    function setLotteryHook(address _lotteryHook) external onlyOwner {
        lotteryHook = _lotteryHook;
    }
    
    /**
     * @notice 铸造彩票代币
     * @dev 只有彩票钩子合约可以调用此函数
     * @param to 接收代币的地址
     * @param amount 要铸造的代币数量
     */
    function mint(address to, uint256 amount) external onlyLottery {
        _mint(to, amount);
    }
    
    /**
     * @notice 销毁彩票代币
     * @dev 只有彩票钩子合约可以调用此函数
     * @param from 要销毁代币的地址
     * @param amount 要销毁的代币数量
     */
    function burn(address from, uint256 amount) external onlyLottery {
        _burn(from, amount);
    }
}