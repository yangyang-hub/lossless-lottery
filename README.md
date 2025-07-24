# 🎰 Uniswap V4 无损彩票钩子

**基于Uniswap V4的创新型无损彩票系统，让流动性提供者通过交易费用自动参与彩票游戏**

## 📋 项目概述

这是一个革命性的区块链彩票系统，结合了Uniswap V4的钩子机制，允许流动性提供者无需额外投入即可参与彩票游戏。系统通过收集交易费用自动构建奖池，参与者不会因为参与彩票而损失本金。

### 🎯 核心特性

- **无损参与**：流动性提供者不会因为参与彩票而损失本金
- **自动彩票**：通过交易费用自动获得彩票参与资格
- **多级奖励**：设置多个奖励等级，提高中奖概率
- **完全去中心化**：基于智能合约运行，无需中心化机构
- **可验证公平**：所有逻辑公开透明，可验证

## 🏗️ 技术架构

### 智能合约组成

#### 1. LotteryHook.sol (主合约)
- **功能**：Uniswap V4钩子合约，负责收集交易费用和管理彩票逻辑
- **关键特性**：
  - 自动收集每笔交易的手续费
  - 将手续费转化为彩票参与资格
  - 管理彩票轮次和时间周期
  - 开奖和中奖者选择机制

#### 2. LotteryTicket.sol (彩票代币)
- **功能**：ERC20代币，代表彩票参与资格
- **功能限制**：
  - 只能由LotteryHook合约铸造和销毁
  - 用于记录用户的彩票参与数量

### 🎲 奖励机制

系统设置了三个奖励等级：

| 等级 | 概率 | 奖励范围 | 描述 |
|------|------|----------|------|
| 小额奖励 | 10% | 1-5 ETH | 高概率小额奖励 |
| 中额奖励 | 5% | 5-20 ETH | 中等概率和奖励 |
| 大额奖励 | 1% | 20-100 ETH | 低概率高额奖励 |

### ⏰ 轮次机制

- **轮次周期**：7天
- **自动轮次**：系统会自动开始和结束轮次
- **奖池累积**：每轮手续费自动进入奖池
- **开奖时间**：轮次结束后可立即开奖

## 🚀 快速开始

### 环境要求

- **Foundry** (稳定版，非夜间版)
- **Node.js** (v16+)
- **Git**

### 安装步骤

1. **克隆项目**
```bash
git clone <your-repo-url>
cd lossless-lottery
```

2. **安装依赖**
```bash
forge install
```

3. **运行测试**
```bash
forge test
```

4. **启动本地测试环境**
```bash
anvil --code-size-limit 40000
```

### 合约部署

#### 本地部署

1. **设置环境变量**
```bash
export PRIVATE_KEY=your_private_key_here
export RPC_URL=http://localhost:8545
```

2. **运行部署脚本**
```bash
forge script script/DeployLotteryHook.s.sol:DeployLotteryHookScript --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

#### 测试网部署 (Sepolia)

1. **设置测试网参数**
```bash
export PRIVATE_KEY=your_private_key_here
export RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY
```

2. **部署到测试网**
```bash
forge script script/DeployLotteryHook.s.sol:DeployLotteryHookScript --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key YOUR_ETHERSCAN_KEY
```

## 📖 使用指南

### 作为流动性提供者参与

1. **添加流动性到支持彩票钩子的交易对**
2. **自动获得彩票代币**：每次交易都会产生手续费，转化为彩票
3. **参与彩票**：使用获得的彩票代币参与当前轮次
4. **等待开奖**：轮次结束后系统自动开奖
5. **领取奖励**：中奖者可领取相应等级的奖励

### 查询轮次信息

```solidity
// 获取当前轮次信息
(
    uint256 roundId,
    uint256 startTime,
    uint256 endTime,
    uint256 totalPool,
    uint256 remainingTime
) = lotteryHook.getCurrentRoundInfo();

// 查询玩家票数
uint256 playerTickets = lotteryHook.getPlayerTickets(roundId, playerAddress);
```

### 参与彩票游戏

```solidity
// 使用彩票代币参与
lotteryHook.enterLottery(playerAddress, ticketAmount);

// 开奖（任何人都可以调用）
lotteryHook.drawWinners(roundId);
```

## 🔧 开发指南

### 项目结构

```
lossless-lottery/
├── src/
│   ├── LotteryHook.sol      # 主彩票钩子合约
│   ├── LotteryTicket.sol    # 彩票代币合约
│   └── Counter.sol          # 示例钩子合约
├── script/
│   ├── DeployLotteryHook.s.sol    # 彩票钩子部署脚本
│   ├── DeploySimple.s.sol        # 简单示例部署
│   └── ...
├── test/
│   ├── LotteryHook.t.sol    # 彩票钩子测试
│   ├── LotteryTicket.t.sol  # 彩票代币测试
│   └── ...
├── lib/                     # 依赖库
├── foundry.toml            # Foundry配置文件
└── README.md               # 项目说明
```

### 运行测试

```bash
# 运行所有测试
forge test

# 运行特定测试文件
forge test --match-path test/LotteryHook.t.sol

# 运行测试并显示日志
forge test -vvv

# 运行测试并生成覆盖率报告
forge coverage
```

### 代码验证

```bash
# 检查合约
forge build

# 运行静态分析
forge fmt --check

# 检查gas使用情况
forge snapshot
```

## ⚠️ 安全警告

### 已知限制

1. **随机数安全**：当前使用区块信息作为随机源，**不适用于生产环境**
   - 建议：生产环境中使用Chainlink VRF或其他安全随机数源

2. **Gas限制**：
   - 参与者数量限制：1000个地址以内
   - 单次开奖最多处理10个奖励等级

3. **权限控制**：
   - 彩票代币只能由钩子合约铸造
   - 合约所有者可以设置钩子地址

### 审计状态

- ⚠️ **开发阶段**：代码尚未经过专业安全审计
- 🔍 **社区审查**：欢迎社区开发者审查代码
- 📋 **测试覆盖**：包含基本功能测试

## 🤝 贡献指南

我们欢迎社区贡献！请按以下步骤操作：

1. **Fork项目**
2. **创建功能分支**：`git checkout -b feature/your-feature`
3. **提交更改**：`git commit -m 'Add some feature'`
4. **推送分支**：`git push origin feature/your-feature`
5. **创建Pull Request**

### 开发规范

- **代码风格**：遵循Solidity官方风格指南
- **测试要求**：所有新功能必须包含测试
- **文档更新**：更新相关文档和注释
- **安全检查**：运行所有安全检查工具

## 📚 相关资源

### 技术文档
- [Uniswap V4 文档](https://docs.uniswap.org/contracts/v4/overview)
- [Foundry 文档](https://book.getfoundry.sh/)
- [OpenZeppelin 合约](https://docs.openzeppelin.com/contracts/4.x/)

### 学习资源
- [v4-by-example.org](https://v4-by-example.org)
- [Uniswap V4 Hooks 教程](https://docs.uniswap.org/contracts/v4/guides/hooks)
- [Solidity 最佳实践](https://consensys.github.io/smart-contract-best-practices/)

### 社区支持
- [Uniswap Discord](https://discord.com/invite/uniswap)
- [Foundry Discord](https://discord.gg/foundry-rs)
- [Ethereum Stack Exchange](https://ethereum.stackexchange.com/)

## 📄 许可证

本项目采用MIT许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

- **Uniswap Foundation**：提供V4钩子模板和开发工具
- **OpenZeppelin**：提供安全合约库
- **Foundry**：提供优秀的开发框架
- **社区贡献者**：感谢所有贡献代码和反馈的开发者

## 📞 联系方式

- **项目维护**：通过GitHub Issues联系
- **技术讨论**：加入项目Discord群组
- **安全报告**：通过GitHub Security页面报告安全问题

---

<div align="center">
  <p><strong>⭐ 如果这个项目对你有帮助，请给我们一个星标！</strong></p>
  <p><sub>Built with ❤️ using Uniswap V4 Hooks and Foundry</sub></p>
</div>