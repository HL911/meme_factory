// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MemeFactory.sol";
import "../src/MemeToken.sol";

contract MemeFactoryTest is Test {
    MemeFactory public factory;
    address public projectOwner;
    address public issuer;
    address public buyer1;
    address public buyer2;
    
    // 测试代币参数
    string constant TOKEN_NAME = "TestMeme";
    string constant TOKEN_SYMBOL = "TMEME";
    uint256 constant TOTAL_SUPPLY = 1000000; // 100万个基本单位
    uint256 constant PER_MINT = 1000; // 每次铸造 1000 个基本单位
    uint256 constant PRICE = 0.001 ether; // 每个基本单位 0.001 ETH
    
    event MemeDeployed(address indexed tokenAddr, string symbol, address indexed issuer);
    event MemeMinted(address indexed tokenAddr, address indexed buyer, uint256 amount);
    
    function setUp() public {
        // 设置测试账户
        projectOwner = makeAddr("projectOwner");
        issuer = makeAddr("issuer");
        buyer1 = makeAddr("buyer1");
        buyer2 = makeAddr("buyer2");
        
        // 给测试账户一些ETH
        vm.deal(issuer, 10 ether);
        vm.deal(buyer1, 10 ether);
        vm.deal(buyer2, 10 ether);
        
        // 部署工厂合约
        factory = new MemeFactory(projectOwner);
    }
    
    function testFactoryDeployment() public {
        // 测试工厂合约部署
        assertEq(factory.projectOwner(), projectOwner);
        assertTrue(address(factory.implementation()) != address(0));
    }
    
    function testDeployMeme() public {
        // 测试部署新的Meme代币
        vm.startPrank(issuer);
        
        // 不检查具体地址，只检查事件的其他参数
        vm.expectEmit(false, false, true, true);
        emit MemeDeployed(address(0), TOKEN_SYMBOL, issuer); // 地址会被忽略
        
        address tokenAddr = factory.deployMeme(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        
        vm.stopPrank();
        
        // 验证代币部署成功
        assertTrue(tokenAddr != address(0));
        assertEq(factory.tokenToIssuer(tokenAddr), issuer);
        
        // 验证代币参数
        MemeToken token = MemeToken(tokenAddr);
        assertEq(token.issuer(), issuer);
        assertEq(token.maxTotalSupply(), TOTAL_SUPPLY);
        assertEq(token.perMint(), PER_MINT);
        assertEq(token.price(), PRICE);
        assertEq(token.mintedAmount(), 0);
    }
    
    function testDeployMemeWithInvalidParams() public {
        vm.startPrank(issuer);
        
        // 测试无效的总供应量
        vm.expectRevert("MemeFactory: total supply must be positive");
        factory.deployMeme(TOKEN_NAME, TOKEN_SYMBOL, 0, PER_MINT, PRICE);
        
        // 测试无效的每次铸造数量
        vm.expectRevert("MemeFactory: per mint must be positive");
        factory.deployMeme(TOKEN_NAME, TOKEN_SYMBOL, TOTAL_SUPPLY, 0, PRICE);
        
        // 测试总供应量不能被每次铸造数量整除
        vm.expectRevert("MemeFactory: total supply must be divisible by per mint");
        factory.deployMeme(TOKEN_NAME, TOKEN_SYMBOL, 1001, 1000, PRICE);
        
        // 测试无效的价格
        vm.expectRevert("MemeFactory: price must be positive");
        factory.deployMeme(TOKEN_NAME, TOKEN_SYMBOL, TOTAL_SUPPLY, PER_MINT, 0);
        
        vm.stopPrank();
    }
    
    function testMintMeme() public {
        // 首先部署一个代币
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        
        // 计算所需费用
        uint256 cost = factory.getMintCost(tokenAddr);
        uint256 expectedCost = PER_MINT * PRICE;
        assertEq(cost, expectedCost);
        
        // 记录初始余额
        uint256 projectOwnerInitialBalance = projectOwner.balance;
        uint256 issuerInitialBalance = issuer.balance;
        uint256 buyer1InitialBalance = buyer1.balance;
        
        // 买家铸造代币
        vm.startPrank(buyer1);
        
        vm.expectEmit(true, true, false, true);
        emit MemeMinted(tokenAddr, buyer1, PER_MINT);
        
        factory.mintMeme{value: cost}(tokenAddr);
        vm.stopPrank();
        
        // 验证铸造结果
        MemeToken token = MemeToken(tokenAddr);
        assertEq(token.balanceOf(buyer1), PER_MINT);
        assertEq(token.mintedAmount(), PER_MINT);
        
        // 验证费用分配
        uint256 projectFee = expectedCost / 100; // 1%
        uint256 issuerFee = expectedCost - projectFee; // 99%
        
        assertEq(projectOwner.balance, projectOwnerInitialBalance + projectFee);
        assertEq(issuer.balance, issuerInitialBalance + issuerFee);
        assertEq(buyer1.balance, buyer1InitialBalance - cost);
    }
    
    function testMintMemeWithOverpayment() public {
        // 部署代币
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        
        uint256 cost = factory.getMintCost(tokenAddr);
        uint256 overpayment = 0.1 ether; // 多付0.1 ETH
        uint256 totalSent = cost + overpayment;
        
        uint256 buyer1InitialBalance = buyer1.balance;
        
        // 买家多付费用铸造代币
        vm.prank(buyer1);
        factory.mintMeme{value: totalSent}(tokenAddr);
        
        // 验证找零正确
        assertEq(buyer1.balance, buyer1InitialBalance - cost);
        
        // 验证代币铸造成功
        MemeToken token = MemeToken(tokenAddr);
        assertEq(token.balanceOf(buyer1), PER_MINT);
    }
    
    function testMintMemeWithInsufficientPayment() public {
        // 部署代币
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        
        uint256 cost = factory.getMintCost(tokenAddr);
        uint256 insufficientAmount = cost - 1; // 少付1 wei
        
        // 测试支付不足
        vm.prank(buyer1);
        vm.expectRevert("MemeFactory: insufficient payment");
        factory.mintMeme{value: insufficientAmount}(tokenAddr);
    }
    
    function testMintMemeInvalidToken() public {
        address invalidToken = makeAddr("invalidToken");
        
        vm.prank(buyer1);
        vm.expectRevert("MemeFactory: invalid token");
        factory.mintMeme{value: 1 ether}(invalidToken);
    }
    
    function testMintMemeSoldOut() public {
        // 部署一个小供应量的代币用于测试售罄
        uint256 smallSupply = PER_MINT; // 只能铸造一次
        
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            smallSupply,
            PER_MINT,
            PRICE
        );
        
        uint256 cost = factory.getMintCost(tokenAddr);
        
        // 第一次铸造成功
        vm.prank(buyer1);
        factory.mintMeme{value: cost}(tokenAddr);
        
        // 第二次铸造应该失败（售罄）
        vm.prank(buyer2);
        vm.expectRevert("MemeFactory: sold out");
        factory.mintMeme{value: cost}(tokenAddr);
    }
    
    function testGetTokenInfo() public {
        // 部署代币
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        
        // 获取代币信息
        (
            uint256 perMint,
            uint256 price,
            uint256 mintedAmount,
            uint256 maxTotalSupply,
            address tokenIssuer
        ) = factory.getTokenInfo(tokenAddr);
        
        // 验证信息正确
        assertEq(perMint, PER_MINT);
        assertEq(price, PRICE);
        assertEq(mintedAmount, 0);
        assertEq(maxTotalSupply, TOTAL_SUPPLY);
        assertEq(tokenIssuer, issuer);
    }
    
    function testGetTokenInfoInvalidToken() public {
        address invalidToken = makeAddr("invalidToken");
        
        vm.expectRevert("MemeFactory: invalid token");
        factory.getTokenInfo(invalidToken);
    }
    
    function testGetMintCostInvalidToken() public {
        address invalidToken = makeAddr("invalidToken");
        
        vm.expectRevert("MemeFactory: invalid token");
        factory.getMintCost(invalidToken);
    }
    
    function testMultipleMints() public {
        // 部署代币
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        
        uint256 cost = factory.getMintCost(tokenAddr);
        
        // 多个用户铸造
        vm.prank(buyer1);
        factory.mintMeme{value: cost}(tokenAddr);
        
        vm.prank(buyer2);
        factory.mintMeme{value: cost}(tokenAddr);
        
        // 验证结果
        MemeToken token = MemeToken(tokenAddr);
        assertEq(token.balanceOf(buyer1), PER_MINT);
        assertEq(token.balanceOf(buyer2), PER_MINT);
        assertEq(token.mintedAmount(), PER_MINT * 2);
        assertEq(token.totalSupply(), PER_MINT * 2); // ERC20的totalSupply应该等于已铸造数量
    }
    
    function testFeeCalculation() public {
        // 部署代币
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        
        uint256 cost = factory.getMintCost(tokenAddr);
        uint256 expectedProjectFee = cost / 100; // 1%
        uint256 expectedIssuerFee = cost - expectedProjectFee; // 99%
        
        uint256 projectOwnerInitialBalance = projectOwner.balance;
        uint256 issuerInitialBalance = issuer.balance;
        
        // 铸造代币
        vm.prank(buyer1);
        factory.mintMeme{value: cost}(tokenAddr);
        
        // 验证费用分配精确性
        assertEq(projectOwner.balance - projectOwnerInitialBalance, expectedProjectFee);
        assertEq(issuer.balance - issuerInitialBalance, expectedIssuerFee);
        assertEq(expectedProjectFee + expectedIssuerFee, cost); // 确保没有费用丢失
    }
}
