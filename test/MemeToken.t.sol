// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MemeToken.sol";
import "../src/MemeFactory.sol";

contract MemeTokenTest is Test {
    MemeFactory public factory;
    MemeToken public token;
    address public projectOwner;
    address public issuer;
    address public minter;
    address public user1;
    address public user2;
    address public tokenAddr;
    
    // 测试参数
    string constant TOKEN_NAME = "TestMeme";
    string constant TOKEN_SYMBOL = "TMEME";
    uint256 constant MAX_TOTAL_SUPPLY = 1000000 * 10**18;
    uint256 constant PER_MINT = 1000 * 10**18;
    uint256 constant PRICE = 0.001 ether;
    
    function setUp() public {
        // 设置测试账户
        projectOwner = makeAddr("projectOwner");
        issuer = makeAddr("issuer");
        minter = makeAddr("minter");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // 部署工厂合约
        factory = new MemeFactory(projectOwner);
        
        // 通过工厂创建代币代理
        vm.prank(issuer);
        tokenAddr = factory.deployMeme(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            MAX_TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        
        // 获取代币代理实例
        token = MemeToken(tokenAddr);
    }
    
    function testInitialization() public {
        // 验证通过工厂初始化的结果
        assertEq(token.name(), TOKEN_NAME);
        assertEq(token.symbol(), TOKEN_SYMBOL);
        assertEq(token.issuer(), issuer);
        assertEq(token.maxTotalSupply(), MAX_TOTAL_SUPPLY);
        assertEq(token.perMint(), PER_MINT);
        assertEq(token.price(), PRICE);
        assertEq(token.mintedAmount(), 0);
        assertEq(token.totalSupply(), 0); // ERC20 totalSupply 初始为0
    }
    
    function testInitializationWithInvalidParams() public {
        // 测试无效参数通过工厂部署
        vm.startPrank(issuer);
        
        // 测试无效总供应量
        vm.expectRevert("MemeFactory: total supply must be positive");
        factory.deployMeme(TOKEN_NAME, TOKEN_SYMBOL, 0, PER_MINT, PRICE);
        
        // 测试无效每次铸造数量
        vm.expectRevert("MemeFactory: per mint must be positive");
        factory.deployMeme(TOKEN_NAME, TOKEN_SYMBOL, MAX_TOTAL_SUPPLY, 0, PRICE);
        
        // 测试无效价格
        vm.expectRevert("MemeFactory: price must be positive");
        factory.deployMeme(TOKEN_NAME, TOKEN_SYMBOL, MAX_TOTAL_SUPPLY, PER_MINT, 0);
        
        vm.stopPrank();
    }
    
    function testDoubleInitialization() public {
        // 尝试再次初始化已初始化的代币
        vm.expectRevert(); // 使用通用的 revert 检查
        token.initialize(
            "AnotherName",
            "ANOTHER",
            MAX_TOTAL_SUPPLY,
            PER_MINT,
            PRICE,
            issuer
        );
    }
    
    function testMintTokens() public {
        // 铸造代币给用户
        token._mintTokens(user1);
        
        // 验证铸造结果
        assertEq(token.balanceOf(user1), PER_MINT);
        assertEq(token.mintedAmount(), PER_MINT);
        assertEq(token.totalSupply(), PER_MINT);
    }
    
    function testMintTokensToZeroAddress() public {
        // 测试铸造到零地址
        vm.expectRevert("MemeToken: mint to zero address");
        token._mintTokens(address(0));
    }
    
    function testMintTokensExceedsMaxSupply() public {
        // 创建一个小供应量的代币用于测试
        uint256 smallMaxSupply = PER_MINT;
        
        vm.prank(issuer);
        address smallTokenAddr = factory.deployMeme(
            "SmallToken",
            "SMALL",
            smallMaxSupply,
            PER_MINT,
            PRICE
        );
        
        MemeToken smallToken = MemeToken(smallTokenAddr);
        
        // 第一次铸造成功
        smallToken._mintTokens(user1);
        assertEq(smallToken.mintedAmount(), PER_MINT);
        
        // 第二次铸造应该失败（超过最大供应量）
        vm.expectRevert("MemeToken: total supply reached");
        smallToken._mintTokens(user2);
    }
    
    function testMultipleMints() public {
        // 多次铸造给不同用户
        token._mintTokens(user1);
        token._mintTokens(user2);
        token._mintTokens(user1); // 给user1再次铸造
        
        // 验证余额
        assertEq(token.balanceOf(user1), PER_MINT * 2);
        assertEq(token.balanceOf(user2), PER_MINT);
        assertEq(token.mintedAmount(), PER_MINT * 3);
        assertEq(token.totalSupply(), PER_MINT * 3);
    }
    
    function testGetMaxTotalSupply() public {
        assertEq(token.getMaxTotalSupply(), MAX_TOTAL_SUPPLY);
    }
    
    function testERC20Functionality() public {
        // 铸造一些代币
        token._mintTokens(user1);
        
        // 测试转账功能
        vm.prank(user1);
        token.transfer(user2, PER_MINT / 2);
        
        assertEq(token.balanceOf(user1), PER_MINT / 2);
        assertEq(token.balanceOf(user2), PER_MINT / 2);
        
        // 测试授权和转账
        vm.prank(user1);
        token.approve(user2, PER_MINT / 4);
        
        vm.prank(user2);
        token.transferFrom(user1, user2, PER_MINT / 4);
        
        assertEq(token.balanceOf(user1), PER_MINT / 4);
        assertEq(token.balanceOf(user2), PER_MINT * 3 / 4);
    }
    
    function testConstructorDisablesInitializers() public {
        // 部署新的代币合约（模板合约）
        MemeToken newToken = new MemeToken();
        
        // 尝试初始化应该失败，因为构造函数禁用了初始化器
        vm.expectRevert();
        newToken.initialize(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            MAX_TOTAL_SUPPLY,
            PER_MINT,
            PRICE,
            issuer
        );
    }
    
    function testMintingProgress() public {
        // 测试铸造进度
        uint256 expectedMints = MAX_TOTAL_SUPPLY / PER_MINT;
        
        for (uint256 i = 0; i < 5; i++) {
            token._mintTokens(user1);
            assertEq(token.mintedAmount(), PER_MINT * (i + 1));
        }
        
        // 验证还可以铸造的数量
        uint256 remainingSupply = MAX_TOTAL_SUPPLY - token.mintedAmount();
        uint256 remainingMints = remainingSupply / PER_MINT;
        
        assertEq(remainingMints, expectedMints - 5);
    }
    
    function testEdgeCaseMaxSupplyReached() public {
        // 创建一个刚好可以铸造两次的代币
        uint256 exactSupply = PER_MINT * 2;
        
        vm.prank(issuer);
        address exactTokenAddr = factory.deployMeme(
            "ExactToken",
            "EXACT",
            exactSupply,
            PER_MINT,
            PRICE
        );
        
        MemeToken exactToken = MemeToken(exactTokenAddr);
        
        // 第一次铸造
        exactToken._mintTokens(user1);
        assertEq(exactToken.mintedAmount(), PER_MINT);
        
        // 第二次铸造
        exactToken._mintTokens(user2);
        assertEq(exactToken.mintedAmount(), PER_MINT * 2);
        assertEq(exactToken.mintedAmount(), exactSupply);
        
        // 第三次铸造应该失败
        vm.expectRevert("MemeToken: total supply reached");
        exactToken._mintTokens(user1);
    }
}
