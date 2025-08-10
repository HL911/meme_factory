// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/UniswapMemeFactory.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract AddLiquidityDebugTest is Test {
    UniswapMemeFactory factory;
    address issuer = address(0x1);
    address buyer = address(0x2);
    
    function setUp() public {
        vm.deal(issuer, 10 ether);
        vm.deal(buyer, 10 ether);
        
        factory = new UniswapMemeFactory();
        
        console.log("=== Test Environment Setup ===");
        console.log("Factory contract address:", address(factory));
    }
    
    function testAddLiquidityStepByStep() public {
        console.log("\n=== Test Add Liquidity Step by Step ===");
        
        // 1. Deploy token
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme(
            "TestToken",
            "TT",
            10000,
            1000,
            0.001 ether
        );
        
        console.log("Token deployed:", tokenAddr);
        
        // 2. Mint some tokens to factory (simulate what mintMeme does)
        UniswapMemeToken token = UniswapMemeToken(tokenAddr);
        uint256 liquidityTokens = 50 * 10**18; // 50 tokens
        
        vm.prank(address(factory));
        token._mintTokens(address(factory), liquidityTokens);
        
        console.log("Factory token balance:", token.balanceOf(address(factory)));
        
        // 3. Create pair if not exists
        IUniswapV2Factory uniswapFactory = factory.uniswapV2FactoryContract();
        address weth = factory.WETH();
        
        address pairAddr = uniswapFactory.getPair(tokenAddr, weth);
        if (pairAddr == address(0)) {
            pairAddr = uniswapFactory.createPair(tokenAddr, weth);
            console.log("Pair created:", pairAddr);
        } else {
            console.log("Pair exists:", pairAddr);
        }
        
        // 4. Approve tokens to router
        vm.prank(address(factory));
        bool approveSuccess = token.approve(address(factory.uniswapV2Router2Contract()), liquidityTokens);
        console.log("Approve success:", approveSuccess);
        
        uint256 allowance = token.allowance(address(factory), address(factory.uniswapV2Router2Contract()));
        console.log("Allowance:", allowance);
        
        // 5. Check router and factory compatibility again
        IUniswapV2Router02 router = factory.uniswapV2Router2Contract();
        console.log("Router factory:", router.factory());
        console.log("Our factory:", address(uniswapFactory));
        console.log("Router WETH:", router.WETH());
        console.log("Our WETH:", weth);
        
        // 6. Try addLiquidityETH with minimal amounts
        uint256 ethAmount = 0.0001 ether; // Very small amount
        uint256 tokenAmount = 1 * 10**18;  // 1 token
        
        console.log("Attempting addLiquidityETH with:");
        console.log("- Token:", tokenAddr);
        console.log("- Token amount:", tokenAmount);
        console.log("- ETH amount:", ethAmount);
        console.log("- To:", address(this));
        console.log("- Deadline:", block.timestamp + 300);
        
        // Give this contract some ETH
        vm.deal(address(this), 1 ether);
        
        // Approve tokens from this contract
        vm.prank(address(factory));
        token.approve(address(router), tokenAmount);
        
        // Transfer tokens to this contract for the test
        vm.prank(address(factory));
        token.transfer(address(this), tokenAmount);
        
        // Approve from this contract to router
        IERC20(tokenAddr).approve(address(router), tokenAmount);
        
        console.log("This contract token balance:", IERC20(tokenAddr).balanceOf(address(this)));
        console.log("This contract ETH balance:", address(this).balance);
        console.log("Allowance to router:", IERC20(tokenAddr).allowance(address(this), address(router)));
        
        try router.addLiquidityETH{value: ethAmount}(
            tokenAddr,
            tokenAmount,
            tokenAmount * 95 / 100,  // 5% slippage
            ethAmount * 95 / 100,    // 5% slippage
            address(this),
            block.timestamp + 300
        ) returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
            console.log("SUCCESS: addLiquidityETH worked!");
            console.log("Amount token:", amountToken);
            console.log("Amount ETH:", amountETH);
            console.log("Liquidity:", liquidity);
        } catch Error(string memory reason) {
            console.log("FAILED: addLiquidityETH failed with reason:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("FAILED: addLiquidityETH failed with low level error");
            console.logBytes(lowLevelData);
        }
    }
    
    function testMinimalLiquidityAdd() public {
        console.log("\n=== Test Minimal Liquidity Add ===");
        
        // Use alternative factory/router addresses
        address altFactory = 0xF62c03E08ada871A0bEb309762E260a7a6a880E6;
        address altRouter = 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3;
        
        console.log("Testing with alternative addresses:");
        console.log("Alt Factory:", altFactory);
        console.log("Alt Router:", altRouter);
        
        // Check if they're compatible
        try IUniswapV2Router02(altRouter).factory() returns (address routerFactory) {
            console.log("Alt Router's factory:", routerFactory);
            
            if (routerFactory == altFactory) {
                console.log("SUCCESS: Alternative Router and Factory are compatible");
            } else {
                console.log("FAILED: Alternative Router and Factory are NOT compatible");
            }
        } catch {
            console.log("FAILED: Cannot get alt router's factory");
        }
    }
}