# 无损彩票合约部署指南

## 项目概述

本项目实现了一个基于Uniswap V4的无损彩票系统，包含两个主要合约：

1. **LotteryTicket.sol** - ERC20彩票代币合约
2. **LotteryHook.sol** - Uniswap V4钩子合约，用于收集交易费用作为彩票奖池

## 合约功能

### LotteryTicket 合约
- ERC20代币，用于代表彩票参与资格
- 仅允许彩票钩子合约铸造和销毁代币
- 支持标准ERC20转账和授权功能

### LotteryHook 合约
- 继承自Uniswap V4 BaseHook
- 收集交易费用作为彩票奖池
- 支持多等级奖励系统
- 自动轮次管理（7天一轮）
- 基于票数的随机中奖机制

## 部署步骤

### 1. 环境准备
确保已安装Foundry工具链：
```bash
forge --version
```

### 2. 运行测试
首先运行所有测试确保合约正确性：

```bash
# 运行LotteryTicket测试
forge test --match-path "test/LotteryTicket.t.sol" -v

# 运行LotteryHook简化测试
forge test --match-path "test/LotteryHookSimple.t.sol" -v
```

### 3. 本地部署

#### 启动本地测试网
```bash
anvil
```

#### 部署彩票代币
```bash
forge script script/DeploySimple.s.sol --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast
```

### 4. 测试网部署（Sepolia）

#### 设置环境变量
```bash
export SEPOLIA_RPC_URL="https://sepolia.infura.io/v3/YOUR_INFURA_KEY"
export PRIVATE_KEY="your-private-key"
```

#### 部署到Sepolia
```bash
forge script script/DeployLotteryHook.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify
```

### 5. 主网部署

注意：由于Uniswap V4尚未在主网部署，主网部署需要等待官方发布。

## 部署注意事项

1. **Hook地址验证**：LotteryHook继承自BaseHook，需要进行地址验证
2. **PoolManager地址**：需要正确设置对应网络的PoolManager地址
3. **权限设置**：部署后需要调用`setLotteryHook`设置彩票钩子地址

## 测试网络地址

### Sepolia测试网
- PoolManager: 0xe03a1074c86CFeDD5C142C4F04F1a1535E203D5f
- LotteryTicket: 待部署
- LotteryHook: 待部署

## 使用方法

### 1. 部署后配置
部署完成后，需要：
1. 设置彩票钩子地址到彩票代币合约
2. 验证合约部署
3. 创建彩票池子（需要与Uniswap V4集成）

### 2. 用户参与流程
1. 用户通过Uniswap V4交易获得彩票代币
2. 使用彩票代币参与彩票游戏
3. 等待轮次结束后开奖
4. 中奖者领取奖励

## 安全警告

⚠️ **重要安全提示：**
- 当前使用区块信息作为随机源，不适用于生产环境
- 生产环境应使用Chainlink VRF或其他安全随机数源
- 合约已包含gas限制和溢出保护
- 建议进行完整的安全审计后再部署到主网

## 相关命令

```bash
# 编译合约
forge build

# 运行所有测试
forge test

# 查看测试覆盖率
forge coverage

# 格式化代码
forge fmt

# 部署到本地
forge script script/DeploySimple.s.sol --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast
```

## 故障排除

### 常见错误及解决方案

1. **HookAddressNotValid错误**：
   - 原因：BaseHook的地址验证失败
   - 解决：使用正确的部署脚本，确保地址格式正确

2. **编译错误**：
   - 确保所有依赖正确安装
   - 检查Solidity版本兼容性

3. **测试失败**：
   - 检查网络连接
   - 确保私钥和RPC URL正确

## 联系和支持

如有问题，请提交GitHub issue或联系开发团队。