// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PermitMemeToken.sol";

contract PermitMemeFactory {
    // 项目方地址（收取5%手续费）
    address public immutable projectOwner;
    
    // 代币模板合约（实现合约）
    PermitMemeToken public immutable implementation;
    
    // 记录所有创建的代币（token地址 => 发行者）
    mapping(address => address) public tokenToIssuer;
    
    // 事件：新代币创建
    event MemeDeployed(address indexed tokenAddr, string symbol, address indexed issuer);
    
    // 事件：代币铸造
    event MemeMinted(address indexed tokenAddr, address indexed buyer, uint256 amount);

    constructor() {
        projectOwner = msg.sender;
        implementation = new PermitMemeToken(); // 部署模板合约
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
        PermitMemeToken(proxy).initialize(
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
        require(tokenToIssuer[tokenAddr] != address(0), "PermitMemeFactory: invalid token");
        
        PermitMemeToken token = PermitMemeToken(tokenAddr);
        address issuer = tokenToIssuer[tokenAddr];
        
        // 校验支付金额
        uint256 requiredPayment = token.price();
        require(msg.value >= requiredPayment, "MemeFactory: insufficient payment");
        
        // 校验是否还有可铸造数量
        require(token.mintedAmount() + token.perMint() <= token.getMaxTotalSupply(), "MemeFactory: sold out");
        
        // 执行铸造
        token._mintTokens(msg.sender);
        
        // 分配费用（基于实际需要的金额，不是用户发送的金额）
        uint256 projectFee = requiredPayment / 20; // 5%给项目方
        uint256 issuerFee = requiredPayment - projectFee; // 95%给发行者
        
        // 转账（使用call确保兼容性）
        (bool projectSuccess, ) = projectOwner.call{value: projectFee}("");
        require(projectSuccess, "MemeFactory: project fee transfer failed");
        
        (bool issuerSuccess, ) = issuer.call{value: issuerFee}("");
        require(issuerSuccess, "MemeFactory: issuer fee transfer failed");
        
        // 找零（如果用户多付了）
        uint256 refund = msg.value - requiredPayment;
        if (refund > 0) {
            (bool refundSuccess, ) = msg.sender.call{value: refund}("");
            require(refundSuccess, "MemeFactory: refund failed");
        }
        
        emit MemeMinted(tokenAddr, msg.sender, token.perMint());
    }

    /**
     * @dev 获取铸造代币所需的费用
     * @param tokenAddr 代币地址
     * @return 所需的ETH数量（wei）
     */
    function getMintCost(address tokenAddr) external view returns (uint256) {
        require(tokenToIssuer[tokenAddr] != address(0), "PermitMemeFactory: invalid token");
        
        PermitMemeToken token = PermitMemeToken(tokenAddr);
        return token.perMint() * token.price();
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
        require(tokenToIssuer[tokenAddr] != address(0), "PermitMemeFactory: invalid token");
        
        PermitMemeToken token = PermitMemeToken(tokenAddr);
        return (
            token.perMint(),
            token.price(),
            token.mintedAmount(),
            token.getMaxTotalSupply(),
            tokenToIssuer[tokenAddr]
        );
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
        
        require(proxy != address(0), "PermitMemeFactory: proxy creation failed");
        return proxy;
    }
}