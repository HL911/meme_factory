// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/UniswapMemeFactory.sol";
import "../src/UniswapMemeToken.sol";

contract UniswapMemeFactoryTest is Test {
    UniswapMemeFactory public factory;
    
    address public projectOwner;
    address public issuer;
    address public buyer1;
    address public buyer2;
    
    // 测试代币参数
    string constant TOKEN_NAME = "TestUniswapMeme";
    string constant TOKEN_SYMBOL = "TUMEME";
    uint256 constant TOTAL_SUPPLY = 1000000; // 100万个代币
    uint256 constant PER_MINT = 1000; // 每次铸造 1000 个代币
    uint256 constant PRICE = 0.001 ether; // 每次铸造费用 0.001 ETH
    
    event MemeDeployed(address indexed tokenAddr, string symbol, address indexed issuer);
    event MemeMinted(address indexed tokenAddr, address indexed buyer, uint256 amount);
    event MemeBought(address indexed tokenAddr, address indexed buyer, uint256 amountETH, uint256 amountToken);
    
    function setUp() public {
        // 设置测试账户
        projectOwner = makeAddr("projectOwner");
        issuer = makeAddr("issuer");
        buyer1 = makeAddr("buyer1");
        buyer2 = makeAddr("buyer2");
        
        // 给测试账户一些ETH
        vm.deal(projectOwner, 100 ether);
        vm.deal(issuer, 100 ether);
        vm.deal(buyer1, 100 ether);
        vm.deal(buyer2, 100 ether);
        
        // 部署工厂合约
        factory = new UniswapMemeFactory();
    }
    
    function testFactoryDeployment() public {
        // 测试工厂合约部署
        assertEq(factory.projectOwner(), address(this)); // 部署者是测试合约
        assertTrue(address(factory.implementation()) != address(0));
        
        // 验证 Uniswap 地址设置
        assertTrue(factory.uniswapV2Factory() != address(0));
        assertTrue(factory.uniswapV2Router2() != address(0));
        assertTrue(factory.WETH() != address(0));
    }
    
    function testDeployMeme() public {
        // 测试部署新的Meme代币
        vm.startPrank(issuer);
        
        vm.expectEmit(false, false, true, true);
        emit MemeDeployed(address(0), TOKEN_SYMBOL, issuer);
        
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
        UniswapMemeToken token = UniswapMemeToken(tokenAddr);
        assertEq(token.issuer(), issuer);
        assertEq(token.getMaxTotalSupply(), TOTAL_SUPPLY * 10**18); // 转换为wei单位
        assertEq(token.perMint(), PER_MINT * 10**18); // 转换为wei单位
        assertEq(token.price(), PRICE);
        assertEq(token.mintedAmount(), 0);
    }
    
    function testDeployMemeWithInvalidParams() public {
        vm.startPrank(issuer);
        
        // 测试无效的总供应量
        vm.expectRevert("PermitMemeFactory: total supply must be positive");
        factory.deployMeme(TOKEN_NAME, TOKEN_SYMBOL, 0, PER_MINT, PRICE);
        
        // 测试无效的每次铸造数量
        vm.expectRevert("PermitMemeFactory: per mint must be positive");
        factory.deployMeme(TOKEN_NAME, TOKEN_SYMBOL, TOTAL_SUPPLY, 0, PRICE);
        
        // 测试总供应量不能被每次铸造数量整除
        vm.expectRevert("PermitMemeFactory: total supply must be divisible by per mint");
        factory.deployMeme(TOKEN_NAME, TOKEN_SYMBOL, 1001, 1000, PRICE);
        
        // 测试无效的价格
        vm.expectRevert("PermitMemeFactory: price must be positive");
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
        assertEq(cost, PRICE);
        
        // 记录初始余额
        uint256 projectOwnerInitialBalance = factory.projectOwner().balance;
        uint256 issuerInitialBalance = issuer.balance;
        uint256 buyer1InitialBalance = buyer1.balance;
        
        // 买家铸造代币
        vm.startPrank(buyer1);
        
        vm.expectEmit(true, true, false, true);
        emit MemeMinted(tokenAddr, buyer1, PER_MINT * 10**18 * 95 / 100); // 用户获得95%（wei单位）
        
        factory.mintMeme{value: cost}(tokenAddr);
        vm.stopPrank();
        
        // 验证铸造结果
        UniswapMemeToken token = UniswapMemeToken(tokenAddr);
        uint256 perMintWei = PER_MINT * 10**18; // 转换为wei单位
        uint256 userTokens = perMintWei * 95 / 100; // 95%给用户
        uint256 liquidityTokens = perMintWei - userTokens; // 5%用于流动性
        
        assertEq(token.balanceOf(buyer1), userTokens);
        assertEq(token.balanceOf(address(factory)), liquidityTokens);
        assertEq(token.mintedAmount(), perMintWei);
        
        // 验证费用分配 (5%给项目方，95%给发行者)
        uint256 projectFee = cost / 20; // 5%
        uint256 issuerFee = cost - projectFee; // 95%
        
        assertEq(factory.projectOwner().balance, projectOwnerInitialBalance + projectFee);
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
        UniswapMemeToken token = UniswapMemeToken(tokenAddr);
        uint256 perMintWei = PER_MINT * 10**18; // 转换为wei单位
        assertEq(token.balanceOf(buyer1), perMintWei * 95 / 100);
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
        vm.expectRevert("UniswapMemeFactory: insufficient payment");
        factory.mintMeme{value: insufficientAmount}(tokenAddr);
    }
    
    function testMintMemeInvalidToken() public {
        address invalidToken = makeAddr("invalidToken");
        
        vm.prank(buyer1);
        vm.expectRevert("UniswapMemeFactory: invalid token");
        factory.mintMeme{value: 1 ether}(invalidToken);
    }
    
    function testMintMemeSoldOut() public {
        // 部署一个小供应量的代币用于测试售罄
        uint256 smallSupply = PER_MINT; // 只能铸造一次（以代币为单位）
        
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
        vm.expectRevert("UniswapMemeFactory: sold out");
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
        assertEq(perMint, PER_MINT * 10**18); // 转换为wei单位
        assertEq(price, PRICE);
        assertEq(mintedAmount, 0);
        assertEq(maxTotalSupply, TOTAL_SUPPLY * 10**18); // 转换为wei单位
        assertEq(tokenIssuer, issuer);
    }
    
    function testGetTokenInfoInvalidToken() public {
        address invalidToken = makeAddr("invalidToken");
        
        vm.expectRevert("UniswapMemeFactory: invalid token");
        factory.getTokenInfo(invalidToken);
    }
    
    function testGetMintCostInvalidToken() public {
        address invalidToken = makeAddr("invalidToken");
        
        vm.expectRevert("UniswapMemeFactory: invalid token");
        factory.getMintCost(invalidToken);
    }
    
    function testBuyMemeWithoutLiquidity() public {
        // 部署代币但不添加流动性
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        
        // 尝试通过 Uniswap 购买应该失败（没有流动性池）
        vm.prank(buyer1);
        vm.expectRevert("UniswapMemeFactory: no liquidity pool exists");
        factory.buyMeme{value: 0.01 ether}(tokenAddr, 1);
    }
    
    function testBuyMemeInvalidToken() public {
        address invalidToken = makeAddr("invalidToken");
        
        vm.prank(buyer1);
        vm.expectRevert("UniswapMemeFactory: invalid token");
        factory.buyMeme{value: 0.01 ether}(invalidToken, 1);
    }
    
    function testBuyMemeWithZeroETH() public {
        // 部署代币
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        
        vm.prank(buyer1);
        vm.expectRevert("UniswapMemeFactory: must send ETH");
        factory.buyMeme{value: 0}(tokenAddr, 1);
    }
    
    function testGetAmountOut() public {
        // 部署代币
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        
        // 没有流动性时应该返回0
        uint256 amountOut = factory.getAmountOut(tokenAddr, 0.01 ether);
        assertEq(amountOut, 0);
    }
    
    function testGetAmountOutInvalidToken() public {
        address invalidToken = makeAddr("invalidToken");
        
        vm.expectRevert("UniswapMemeFactory: invalid token");
        factory.getAmountOut(invalidToken, 0.01 ether);
    }
    
    function testComparePrices() public {
        // 部署代币
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        
        // 获取价格比较
        (uint256 mintPrice, uint256 uniswapPrice, bool isBetter) = factory.comparePrices(tokenAddr);
        
        // 验证铸币价格正确
        assertEq(mintPrice, PRICE / PER_MINT); // 每个代币的价格
        
        // 没有流动性时，Uniswap价格应该是0，不会更优
        assertEq(uniswapPrice, 0);
        assertFalse(isBetter);
    }
    
    function testComparePricesInvalidToken() public {
        address invalidToken = makeAddr("invalidToken");
        
        vm.expectRevert("UniswapMemeFactory: invalid token");
        factory.comparePrices(invalidToken);
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
        UniswapMemeToken token = UniswapMemeToken(tokenAddr);
        uint256 perMintWei = PER_MINT * 10**18; // 转换为wei单位
        uint256 userTokens = perMintWei * 95 / 100; // 每个用户获得95%
        uint256 totalLiquidityTokens = (perMintWei * 5 / 100) * 2; // 总共10%用于流动性
        
        assertEq(token.balanceOf(buyer1), userTokens);
        assertEq(token.balanceOf(buyer2), userTokens);
        assertEq(token.balanceOf(address(factory)), totalLiquidityTokens);
        assertEq(token.mintedAmount(), perMintWei * 2);
    }
    
    function testFeeCalculationPrecision() public {
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
        uint256 expectedProjectFee = cost / 20; // 5%
        uint256 expectedIssuerFee = cost - expectedProjectFee; // 95%
        
        uint256 projectOwnerInitialBalance = factory.projectOwner().balance;
        uint256 issuerInitialBalance = issuer.balance;
        
        // 铸造代币
        vm.prank(buyer1);
        factory.mintMeme{value: cost}(tokenAddr);
        
        // 验证费用分配精确性
        assertEq(factory.projectOwner().balance - projectOwnerInitialBalance, expectedProjectFee);
        assertEq(issuer.balance - issuerInitialBalance, expectedIssuerFee);
        assertEq(expectedProjectFee + expectedIssuerFee, cost); // 确保没有费用丢失
    }
    
    function testTokenDistributionPrecision() public {
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
        
        // 铸造代币
        vm.prank(buyer1);
        factory.mintMeme{value: cost}(tokenAddr);
        
        // 验证代币分配精确性
        UniswapMemeToken token = UniswapMemeToken(tokenAddr);
        uint256 perMintWei = PER_MINT * 10**18; // 转换为wei单位
        uint256 userTokens = perMintWei * 95 / 100; // 95%给用户
        uint256 liquidityTokens = perMintWei - userTokens; // 5%用于流动性
        
        assertEq(token.balanceOf(buyer1), userTokens);
        assertEq(token.balanceOf(address(factory)), liquidityTokens);
        assertEq(userTokens + liquidityTokens, perMintWei); // 确保没有代币丢失
    }
    
    function testLiquidityTokensAccumulation() public {
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
        UniswapMemeToken token = UniswapMemeToken(tokenAddr);
        
        // 第一次铸造
        vm.prank(buyer1);
        factory.mintMeme{value: cost}(tokenAddr);
        
        uint256 liquidityAfterFirst = token.balanceOf(address(factory));
        uint256 perMintWei = PER_MINT * 10**18; // 转换为wei单位
        assertEq(liquidityAfterFirst, perMintWei * 5 / 100);
        
        // 第二次铸造
        vm.prank(buyer2);
        factory.mintMeme{value: cost}(tokenAddr);
        
        uint256 liquidityAfterSecond = token.balanceOf(address(factory));
        assertEq(liquidityAfterSecond, (perMintWei * 5 / 100) * 2);
        
        // 验证流动性代币累积正确
        assertEq(liquidityAfterSecond, liquidityAfterFirst * 2);
    }
    
    function testEdgeCaseSmallAmounts() public {
        // 测试小数量的代币和费用
        uint256 smallPerMint = 100;
        uint256 smallPrice = 1000; // 1000 wei
        
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            smallPerMint * 10, // 总供应量
            smallPerMint,
            smallPrice
        );
        
        uint256 cost = factory.getMintCost(tokenAddr);
        assertEq(cost, smallPrice);
        
        // 铸造代币
        vm.prank(buyer1);
        factory.mintMeme{value: cost}(tokenAddr);
        
        // 验证小数量的分配
        UniswapMemeToken token = UniswapMemeToken(tokenAddr);
        uint256 smallPerMintWei = smallPerMint * 10**18; // 转换为wei单位
        uint256 userTokens = smallPerMintWei * 95 / 100; // 95%代币
        uint256 liquidityTokens = smallPerMintWei - userTokens; // 5%代币
        
        assertEq(token.balanceOf(buyer1), userTokens);
        assertEq(token.balanceOf(address(factory)), liquidityTokens);
    }
    
    function testMaxSupplyReached() public {
        // 部署一个只能铸造两次的代币
        uint256 limitedSupply = PER_MINT * 2;
        
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            limitedSupply,
            PER_MINT,
            PRICE
        );
        
        uint256 cost = factory.getMintCost(tokenAddr);
        
        // 第一次铸造
        vm.prank(buyer1);
        factory.mintMeme{value: cost}(tokenAddr);
        
        // 第二次铸造
        vm.prank(buyer2);
        factory.mintMeme{value: cost}(tokenAddr);
        
        // 第三次铸造应该失败
        vm.prank(buyer1);
        vm.expectRevert("UniswapMemeFactory: sold out");
        factory.mintMeme{value: cost}(tokenAddr);
        
        // 验证总供应量
        UniswapMemeToken token = UniswapMemeToken(tokenAddr);
        assertEq(token.mintedAmount(), limitedSupply * 10**18); // 转换为wei单位
    }
}