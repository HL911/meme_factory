// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UniswapMemeToken.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract UniswapMemeFactory {
    // 项目方地址（收取5%手续费）
    address public immutable projectOwner;
    
    // 代币模板合约（实现合约）
    UniswapMemeToken public immutable implementation;

    // v2_factory地址 (匹配新Router配置)
    address public immutable uniswapV2Factory = 0x42Fee1219748f7A5411e6C13d822D2d935D9c4A1;
    IUniswapV2Factory public immutable uniswapV2FactoryContract = IUniswapV2Factory(uniswapV2Factory);

    // v2_router2地址
    address public immutable uniswapV2Router2 =0xd2268B943Fa81ac0600b753CE1c9C18BC805f89F;
    IUniswapV2Router02 public immutable uniswapV2Router2Contract = IUniswapV2Router02(uniswapV2Router2);

    // WETH地址
    address public immutable WETH = 0x127Abc00C9Fef19a9690f890711670695324c489;
    
    // 记录所有创建的代币（token地址 => 发行者）
    mapping(address => address) public tokenToIssuer;
    
    // 事件：新代币创建
    event MemeDeployed(address indexed tokenAddr, string symbol, address indexed issuer);
    
    // 事件：代币铸造
    event MemeMinted(address indexed tokenAddr, address indexed buyer, uint256 amount);
    
    // 事件：通过 Uniswap 购买代币
    event MemeBought(address indexed tokenAddr, address indexed buyer, uint256 amountETH, uint256 amountToken);

    constructor() {
        projectOwner = msg.sender;
        implementation = new UniswapMemeToken(); // 部署模板合约
    }

    /**
     * @dev 发行者创建新Meme代币
     * @param name 代币名称
     * @param symbol 代币符号
     * @param totalSupply 总供应量（以代币为单位，如 10000 表示1万个代币）
     * @param perMint 每次铸造数量（以代币为单位，如 1000 表示1千个代币）
     * @param price 每次铸造的总费用（wei，如 100000000000000 表示0.0001ETH）
     * @return 新代币地址
     */
    function deployMeme(
        string calldata name,
        string calldata symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address) {
        // 校验参数
        require(totalSupply > 0, "PermitMemeFactory: total supply must be positive");
        require(perMint > 0, "PermitMemeFactory: per mint must be positive");
        require(totalSupply % perMint == 0, "PermitMemeFactory: total supply must be divisible by per mint");
        require(price > 0, "PermitMemeFactory: price must be positive");

        // 创建最小代理
        address proxy = _createProxy();
        
        // 初始化代理（调用模板合约的initialize函数）
        UniswapMemeToken(proxy).initialize(
            name,
            symbol,
            totalSupply,
            perMint,
            price,
            msg.sender // 发行者为调用者
        );
        
        // 记录代币信息
        tokenToIssuer[proxy] = msg.sender;
        
        emit MemeDeployed(proxy, symbol, msg.sender);
        return proxy;
    }

    /**
     * @dev 用户铸造Meme代币
     * @param tokenAddr 代币地址
     */
    function mintMeme(address tokenAddr) external payable {
        // 校验代币是否存在
        require(tokenToIssuer[tokenAddr] != address(0), "UniswapMemeFactory: invalid token");
        
        UniswapMemeToken token = UniswapMemeToken(tokenAddr);
        address issuer = tokenToIssuer[tokenAddr];
        
        // 校验支付金额
        uint256 requiredPayment = token.price();
        require(msg.value >= requiredPayment, "UniswapMemeFactory: insufficient payment");
        
        // 计算代币分配：95%给用户，5%用于流动性
        uint256 userTokens = token.perMint() * 95 / 100;
        uint256 liquidityTokens = token.perMint() - userTokens;
        
        // 校验是否还有可铸造数量
        require(token.mintedAmount() + token.perMint() <= token.getMaxTotalSupply(), "UniswapMemeFactory: sold out");
        
        // 执行铸造：95%给用户，5%给工厂合约用于流动性
        token._mintTokens(msg.sender, userTokens);
        token._mintTokens(address(this), liquidityTokens);
        
        // 分配费用（基于实际需要的金额，不是用户发送的金额）
        uint256 projectFee = requiredPayment / 20; // 5%给项目方
        uint256 issuerFee = requiredPayment - projectFee; // 95%给发行者

        // 转账给发行者（使用call确保兼容性）
        (bool issuerSuccess, ) = issuer.call{value: issuerFee}("");
        require(issuerSuccess, "UniswapMemeFactory: issuer fee transfer failed");

        // 找零（如果用户多付了）
        uint256 refund = msg.value - requiredPayment;
        if (refund > 0) {
            (bool refundSuccess, ) = msg.sender.call{value: refund}("");
            require(refundSuccess, "UniswapMemeFactory: refund failed");
        }

        // 检查是否有流动性池子
        address pairAddr = uniswapV2FactoryContract.getPair(tokenAddr, WETH);
        bool isFirstLiquidity = (pairAddr == address(0));
        
        if (isFirstLiquidity) {
            // 如果没有流动性池子，创建一个
            uniswapV2FactoryContract.createPair(tokenAddr, WETH);
        }

        // 授权代币给 Router 合约（代币已经在工厂合约中）
        token.approve(address(uniswapV2Router2Contract), liquidityTokens);
        
        // 添加流动性：使用项目方的5%ETH费用 + 5%代币
        uniswapV2Router2Contract.addLiquidityETH{value: projectFee}(
            tokenAddr,
            liquidityTokens,
            liquidityTokens * 95 / 100, // 最小代币数量（允许5%滑点）
            projectFee * 95 / 100,      // 最小ETH数量（允许5%滑点）
            projectOwner,               // LP代币接收者
            block.timestamp + 300       // 5分钟超时
        );
        
        emit MemeMinted(tokenAddr, msg.sender, userTokens);
    }

    /**
     * @dev 获取铸造代币所需的费用
     * @param tokenAddr 代币地址
     * @return 所需的ETH数量（wei）
     */
    function getMintCost(address tokenAddr) external view returns (uint256) {
        require(tokenToIssuer[tokenAddr] != address(0), "UniswapMemeFactory: invalid token");
        
        UniswapMemeToken token = UniswapMemeToken(tokenAddr);
        return token.price();
    }

    /**
     * @dev 获取代币的详细信息
     * @param tokenAddr 代币地址
     * @return perMint 每次铸造数量
     * @return price 单价
     * @return mintedAmount 已铸造数量
     * @return maxTotalSupply 最大总供应量
     * @return issuer 发行者地址
     */
    function getTokenInfo(address tokenAddr) external view returns (
        uint256 perMint,
        uint256 price,
        uint256 mintedAmount,
        uint256 maxTotalSupply,
        address issuer
    ) {
        require(tokenToIssuer[tokenAddr] != address(0), "UniswapMemeFactory: invalid token");
        
        UniswapMemeToken token = UniswapMemeToken(tokenAddr);
        return (
            token.perMint(),
            token.price(),
            token.mintedAmount(),
            token.getMaxTotalSupply(),
            tokenToIssuer[tokenAddr]
        );
    }

    /**
     * @dev 通过 Uniswap 购买 Meme 代币（当价格优于起始价格时）
     * @param tokenAddr 代币地址
     * @param minAmountOut 最小输出代币数量
     */
    function buyMeme(address tokenAddr, uint256 minAmountOut) external payable {
        // 校验代币是否存在
        require(tokenToIssuer[tokenAddr] != address(0), "UniswapMemeFactory: invalid token");
        require(msg.value > 0, "UniswapMemeFactory: must send ETH");
        
        // 检查是否有流动性池
        address pairAddr = uniswapV2FactoryContract.getPair(tokenAddr, WETH);
        require(pairAddr != address(0), "UniswapMemeFactory: no liquidity pool exists");
        
        // 检查 Uniswap 价格是否优于起始价格
        require(_isUniswapPriceBetter(tokenAddr), "UniswapMemeFactory: Uniswap price not better than mint price");
        
        // 构建交换路径：ETH -> WETH -> Token
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = tokenAddr;
        
        // 通过 Uniswap 购买代币
        uint256[] memory amounts = uniswapV2Router2Contract.swapExactETHForTokens{value: msg.value}(
            minAmountOut,
            path,
            msg.sender,
            block.timestamp + 300 // 5分钟超时
        );
        
        emit MemeBought(tokenAddr, msg.sender, msg.value, amounts[1]);
    }
    
    /**
     * @dev 获取在 Uniswap 上用指定 ETH 数量能购买到的代币数量
     * @param tokenAddr 代币地址
     * @param amountETH ETH 数量
     * @return 能购买到的代币数量
     */
    function getAmountOut(address tokenAddr, uint256 amountETH) external view returns (uint256) {
        require(tokenToIssuer[tokenAddr] != address(0), "UniswapMemeFactory: invalid token");
        
        // 检查是否有流动性池
        address pairAddr = uniswapV2FactoryContract.getPair(tokenAddr, WETH);
        if (pairAddr == address(0)) {
            return 0; // 没有流动性池
        }
        
        // 构建交换路径
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = tokenAddr;
        
        try uniswapV2Router2Contract.getAmountsOut(amountETH, path) returns (uint256[] memory amounts) {
            return amounts[1];
        } catch {
            return 0;
        }
    }
    
    /**
     * @dev 检查 Uniswap 价格是否优于起始铸币价格
     * @param tokenAddr 代币地址
     * @return 如果 Uniswap 价格更优则返回 true
     */
    function _isUniswapPriceBetter(address tokenAddr) internal view returns (bool) {
        UniswapMemeToken token = UniswapMemeToken(tokenAddr);
        uint256 mintPrice = token.price(); // 铸造一次的 ETH 费用
        uint256 perMint = token.perMint(); // 铸造一次的代币数量
        
        // 计算在 Uniswap 上用相同 ETH 能买到多少代币
        uint256 uniswapAmount = this.getAmountOut(tokenAddr, mintPrice);
        
        // 如果在 Uniswap 上能买到更多代币，则价格更优
        return uniswapAmount > perMint;
    }
    
    /**
     * @dev 比较铸币价格和 Uniswap 价格
     * @param tokenAddr 代币地址
     * @return mintPrice 铸币价格（每个代币的 ETH 成本）
     * @return uniswapPrice 当前 Uniswap 价格（每个代币的 ETH 成本）
     * @return isBetter Uniswap 价格是否更优
     */
    function comparePrices(address tokenAddr) external view returns (
        uint256 mintPrice,
        uint256 uniswapPrice,
        bool isBetter
    ) {
        require(tokenToIssuer[tokenAddr] != address(0), "UniswapMemeFactory: invalid token");
        
        UniswapMemeToken token = UniswapMemeToken(tokenAddr);
        uint256 mintCost = token.price(); // 铸造一次的 ETH 费用
        uint256 perMint = token.perMint(); // 铸造一次的代币数量
        
        // 铸币价格：每个代币的 ETH 成本
        mintPrice = mintCost * 1e18 / perMint;
        
        // 获取 Uniswap 价格
        uint256 uniswapAmount = this.getAmountOut(tokenAddr, mintCost);
        if (uniswapAmount > 0) {
            uniswapPrice = mintCost * 1e18 / uniswapAmount;
            isBetter = uniswapAmount > perMint; // 相同 ETH 能买到更多代币
        } else {
            uniswapPrice = 0;
            isBetter = false;
        }
    }

    /**
     * @dev 创建最小代理（核心逻辑）
     */
    function _createProxy() internal returns (address) {
        // 最小代理的字节码（EIP-1167标准）
        bytes memory proxyCode = abi.encodePacked(
            hex"3d602d80600a3d3981f3363d3d373d3d3d363d73",
            address(implementation),
            hex"5af43d82803e903d91602b57fd5bf3"
        );
        
        // 部署代理合约
        address proxy;
        assembly {
            proxy := create(0, add(proxyCode, 0x20), mload(proxyCode))
        }
        
        require(proxy != address(0), "UniswapMemeFactory: proxy creation failed");
        return proxy;
    }
}