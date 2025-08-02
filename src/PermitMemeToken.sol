// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin-upgradeable/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";

contract PermitMemeToken is Initializable, ERC20PermitUpgradeable {
    // 代币元数据（实际存储在代理中）
    address public issuer;          // 发行者地址
    uint256 public maxTotalSupply;  // 最大总供应量（最小单位，已乘以10^18）
    uint256 public perMint;         // 每次铸造数量（最小单位，已乘以10^18）
    uint256 public price;           // 每次铸造的总费用（wei）
    uint256 public mintedAmount;    // 已铸造数量（最小单位，已乘以10^18）

    // 构造函数（禁用初始化器）
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    // 初始化函数（仅代理部署时调用一次）
    function initialize(
        string memory name,
        string memory symbol,
        uint256 _totalSupply,    // 以代币为单位，如 10000 表示1万个代币
        uint256 _perMint,        // 以代币为单位，如 1000 表示1千个代币
        uint256 _price,          // 每次铸造的总费用（wei，如 100000000000000 表示0.0001ETH）
        address _issuer
    ) external initializer {
        require(_issuer != address(0), "MemeToken: invalid issuer");
        require(_totalSupply > 0, "MemeToken: invalid total supply");
        require(_perMint > 0, "MemeToken: invalid per mint");
        require(_price > 0, "MemeToken: invalid price");
        
        // 初始化 ERC20 的名称和符号
        __ERC20_init(name, symbol);
        // 初始化 permit 功能
        __ERC20Permit_init(name);  
        
        // 自动转换精度：将代币数量转换为最小单位
        maxTotalSupply = _totalSupply * 10**decimals();
        perMint = _perMint * 10**decimals();
        price = _price;
        issuer = _issuer;
        mintedAmount = 0;
    }

    // 内部铸造函数（仅工厂可调用）
    function _mintTokens(address to) external {
        require(to != address(0), "MemeToken: mint to zero address");
        // 校验逻辑（由工厂控制，此处简化）
        require(mintedAmount + perMint <= maxTotalSupply, "MemeToken: total supply reached");
        
        // 执行铸造
        _mint(to, perMint);
        mintedAmount += perMint;
    }
    
    // 获取最大总供应量
    function getMaxTotalSupply() external view returns (uint256) {
        return maxTotalSupply;
    }
}