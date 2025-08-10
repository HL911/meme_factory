# MemeFactory - 去中心化 Meme 代币工厂

一个基于以太坊的去中心化 Meme 代币创建和交易平台，使用 EIP-1167 最小代理模式实现高效的代币部署，并集成 Uniswap V2 实现去中心化交易。

## 🚀 项目特性

- **🏭 代币工厂模式**: 任何人都可以创建自己的 Meme 代币
- **⚡ 最小代理模式**: 使用 EIP-1167 标准，大幅降低部署成本
- **💰 自动费用分配**: 1% 平台费用，99% 发行者收益
- **🔄 多付自动找零**: 支持用户多付，自动退还多余费用
- **🛡️ 安全可升级**: 基于 OpenZeppelin Upgradeable 合约
- **🔗 Uniswap 集成**: 支持通过 Uniswap V2 进行代币交易
- **💱 价格查询**: 实时获取代币在 Uniswap 上的交易价格
- **📊 完整测试覆盖**: 30+个测试用例，全面覆盖各种场景

## 📋 合约架构

### MemeFactory.sol
基础工厂合约，负责：
- 创建新的 Meme 代币（使用最小代理）
- 处理代币铸造和费用分配
- 提供查询接口

### MemeToken.sol
基础代币模板合约，特性：
- 标准 ERC20 功能
- 可配置的铸造参数
- 供应量限制
- 代理模式初始化

### UniswapMemeFactory.sol
增强版工厂合约，在基础功能上增加：
- 集成 Uniswap V2 协议
- 支持代币交易功能 (`buyMeme`)
- 实时价格查询 (`getAmountOut`)
- 价格比较功能 (`comparePrices`)

### UniswapMemeToken.sol
增强版代币模板合约，特性：
- 继承所有基础 ERC20 功能
- 优化的初始化流程
- 与 Uniswap 协议兼容

## 🛠️ 技术栈

- **Solidity**: ^0.8.0
- **Foundry**: 开发框架
- **OpenZeppelin**: 安全合约库
- **EIP-1167**: 最小代理标准
- **Uniswap V2**: 去中心化交易协议
- **WETH**: 包装以太坊代币标准

## 📦 安装和设置

### 前置要求
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js (可选，用于前端集成)

### 克隆项目
```bash
git clone <your-repo-url>
cd meme_factory
```

### 安装依赖
```bash
forge install
```

### 编译合约
```bash
forge build
```

### 运行测试
```bash
forge test
```

## 🎯 使用指南

### 基础版本 (MemeFactory)

#### 1. 部署工厂合约

```solidity
// 部署时需要指定项目方地址（接收1%费用）
MemeFactory factory = new MemeFactory(projectOwnerAddress);
```

#### 2. 创建 Meme 代币

```solidity
address tokenAddr = factory.deployMeme(
    "MyMeme",           // 代币名称
    "MEME",             // 代币符号
    1000000,            // 总供应量
    1000,               // 每次铸造数量
    10000000000000      // 单价 (wei)
);
```

#### 3. 铸造代币

```solidity
// 查询铸造费用
uint256 cost = factory.getMintCost(tokenAddr);

// 铸造代币（支持多付找零）
factory.mintMeme{value: cost}(tokenAddr);
```

### 增强版本 (UniswapMemeFactory)

#### 1. 部署增强版工厂合约

```solidity
// 部署时需要指定项目方地址和WETH地址
UniswapMemeFactory factory = new UniswapMemeFactory(
    projectOwnerAddress,
    wethAddress
);
```

#### 2. 创建 Meme 代币

```solidity
address tokenAddr = factory.deployMeme(
    "MyMeme",           // 代币名称
    "MEME",             // 代币符号
    1000000,            // 总供应量
    1000,               // 每次铸造数量
    1000000000000000    // 单价 (wei, 建议0.001 ETH)
);
```

#### 3. 铸造代币

```solidity
// 查询铸造费用
uint256 cost = factory.getMintCost(tokenAddr);

// 铸造代币（支持多付找零）
factory.mintMeme{value: cost}(tokenAddr);
```

#### 4. 交易代币 (通过 Uniswap)

```solidity
// 查询可获得的代币数量
uint256 amountOut = factory.getAmountOut(tokenAddr, 1 ether);

// 购买代币（需要存在流动性池）
factory.buyMeme{value: 1 ether}(tokenAddr, amountOut);
```

#### 5. 价格比较

```solidity
// 比较铸造价格和市场价格
(uint256 mintPrice, uint256 marketPrice) = factory.comparePrices(tokenAddr, 1000);
```

## 💰 价格设置建议

根据用户反馈和经济模型分析，建议的价格范围：

| 价格等级 | 单价 (wei) | 单价 (ETH) | 每次铸造费用* |
|---------|-----------|-----------|-------------|
| 超低价 | 1,000,000,000,000 | 0.000001 | ~0.001 ETH |
| 低价 | 10,000,000,000,000 | 0.00001 | ~0.01 ETH |
| 中等价 | 100,000,000,000,000 | 0.0001 | ~0.1 ETH |
| 较高价 | 1,000,000,000,000,000 | 0.001 | ~1 ETH |

*假设每次铸造 1000 个代币

## 🔧 在 Etherscan 上使用

### 部署代币 (deployMeme)

**参数说明：**
- `name`: 代币名称 (string)
- `symbol`: 代币符号 (string)
- `totalSupply`: 总供应量 (uint256)
- `perMint`: 每次铸造数量 (uint256)
- `price`: 单价，单位为 **wei** (uint256)

**示例：**
```
name: "TestMeme"
symbol: "TEST"
totalSupply: 1000000
perMint: 1000
price: 1000000000000000  // 0.001 ETH (推荐价格)
```

### 铸造代币 (mintMeme)

**参数说明：**
- `tokenAddr`: 代币合约地址 (address)
- `payableAmount`: 支付的 ETH 数量

**操作步骤：**
1. 调用 `getMintCost(tokenAddr)` 查询所需费用
2. 将返回的 wei 转换为 ETH
3. 在 `payableAmount` 中输入 ETH 数量

### 购买代币 (buyMeme) - UniswapMemeFactory 专用

**参数说明：**
- `tokenAddr`: 代币合约地址 (address)
- `minAmountOut`: 最少获得的代币数量 (uint256)
- `payableAmount`: 支付的 ETH 数量

**操作步骤：**
1. 调用 `getAmountOut(tokenAddr, ethAmount)` 查询可获得的代币数量
2. 设置 `minAmountOut` 为预期数量的 95%（防止滑点）
3. 在 `payableAmount` 中输入要支付的 ETH 数量
4. 调用 `buyMeme` 函数

**示例：**
```
tokenAddr: 0x1234...  // 代币合约地址
minAmountOut: 950     // 最少获得950个代币（假设预期1000个）
payableAmount: 1      // 支付1 ETH
```

### 价格查询功能

#### getAmountOut
查询用指定数量的 ETH 可以购买多少代币：
```
tokenAddr: 0x1234...
ethAmount: 1000000000000000000  // 1 ETH (in wei)
```

#### comparePrices
比较铸造价格和市场价格：
```
tokenAddr: 0x1234...
tokenAmount: 1000  // 1000个代币
```
返回：`(mintPrice, marketPrice)` 都以 wei 为单位

## 📊 测试覆盖

项目包含 30+ 个全面的测试用例：

### MemeFactory 测试 (13个)
- ✅ 工厂部署测试
- ✅ 代币部署测试
- ✅ 参数验证测试
- ✅ 代币铸造测试
- ✅ 多付找零测试
- ✅ 支付不足测试
- ✅ 售罄测试
- ✅ 费用分配测试
- ✅ 多次铸造测试
- ✅ 辅助函数测试
- ✅ 无效代币测试
- ✅ 费用计算精确性测试

### MemeToken 测试 (12个)
- ✅ 初始化测试
- ✅ 参数验证测试
- ✅ 重复初始化测试
- ✅ 铸造功能测试
- ✅ 零地址保护测试
- ✅ 供应量限制测试
- ✅ 多次铸造测试
- ✅ ERC20功能测试
- ✅ 构造函数测试
- ✅ 铸造进度测试
- ✅ 边界情况测试
- ✅ 辅助函数测试

### UniswapMemeFactory 测试 (6个)
- ✅ buyMeme 基本验证测试
- ✅ buyMeme 代币信息测试
- ✅ buyMeme 工作流程测试
- ✅ getAmountOut 功能测试
- ✅ comparePrices 功能测试
- ✅ Uniswap 集成测试

### 其他专项测试 (10+个)
- ✅ WETH 集成测试
- ✅ Uniswap 地址验证测试
- ✅ 流动性池创建测试
- ✅ 价格查询测试
- ✅ 错误处理测试
- ✅ 边界条件测试
- ✅ 安全性测试

运行测试：
```bash
forge test -vv
```

## 🔒 安全特性

- **重入攻击保护**: 使用 checks-effects-interactions 模式
- **初始化保护**: 防止重复初始化和直接调用模板合约
- **参数验证**: 全面的输入参数检查
- **溢出保护**: 使用 Solidity 0.8+ 内置溢出检查
- **访问控制**: 合理的权限管理

## 📈 Gas 优化

- **最小代理模式**: 每次部署仅需 ~45,000 gas
- **批量操作**: 支持高效的批量铸造
- **存储优化**: 合理的存储布局设计

## 🌐 部署指南

### 测试网部署

```bash
# 设置环境变量
export PRIVATE_KEY="your_private_key"
export RPC_URL="https://sepolia.infura.io/v3/your_key"

# 部署到 Sepolia 测试网
forge script script/Deploy.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### 主网部署

```bash
# 主网部署（请谨慎操作）
forge script script/Deploy.s.sol --rpc-url https://mainnet.infura.io/v3/your_key --private-key $PRIVATE_KEY --broadcast --verify
```

## 🤝 贡献指南

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🔗 相关链接

- [Foundry 文档](https://book.getfoundry.sh/)
- [OpenZeppelin 合约](https://docs.openzeppelin.com/contracts/)
- [EIP-1167 标准](https://eips.ethereum.org/EIPS/eip-1167)

## ❓ 常见问题

### Q: 为什么使用最小代理模式？
A: 最小代理模式可以大幅降低部署成本，每次部署新代币只需要约 45,000 gas，而不是完整部署的 200,000+ gas。

### Q: 如何设置合理的代币价格？
A: 建议根据目标用户群体设置价格。对于大众化的 Meme 代币，建议使用较低价格（0.001-0.01 ETH per token）以降低参与门槛。

### Q: 费用是如何分配的？
A: 每次铸造的费用中，1% 归平台方，99% 归代币发行者。这个比例在合约中固定，无法修改。

### Q: 代币铸造完后还能继续铸造吗？
A: 不能。当代币达到最大供应量后，将无法继续铸造，合约会抛出 "sold out" 错误。

### Q: buyMeme 功能是如何工作的？
A: buyMeme 功能通过 Uniswap V2 协议实现代币交易。它会查询指定代币在 Uniswap 上的流动性池，并根据当前汇率进行代币交换。需要注意的是，只有在 Uniswap 上存在该代币的流动性池时才能使用此功能。

### Q: 为什么 buyMeme 有时会失败？
A: buyMeme 失败的常见原因包括：
- 代币在 Uniswap 上没有流动性池
- 滑点过大（实际价格与预期价格差异太大）
- 支付的 ETH 数量不足
- 网络拥堵导致交易失败

### Q: MemeFactory 和 UniswapMemeFactory 有什么区别？
A: MemeFactory 是基础版本，只提供代币创建和铸造功能。UniswapMemeFactory 是增强版本，在基础功能上增加了 Uniswap 集成，支持代币交易、价格查询等功能。

### Q: 如何为我的代币创建流动性池？
A: 需要在 Uniswap 上手动添加流动性。首先铸造一定数量的代币，然后在 Uniswap 界面上创建 ETH/代币 交易对并添加流动性。

---

**⚠️ 免责声明**: 本项目仅供学习和研究使用。在主网部署前请进行充分的安全审计。投资有风险，请谨慎参与。
