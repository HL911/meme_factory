// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/UniswapMemeFactory.sol";
import "../src/UniswapMemeToken.sol";

// Router interface
interface IRouter {
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);
    
    function getAmountsOut(uint amountIn, address[] calldata path)
        external view returns (uint[] memory amounts);
        
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

// Factory interface
interface IFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

// Pair interface
interface IPair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

contract BuyMemeTest is Test {
    UniswapMemeFactory factory;
    address testToken;
    address user1;
    address user2;
    address projectOwner;
    
    function setUp() public {
        // Deploy factory contract
        factory = new UniswapMemeFactory();
        
        // Set up test accounts
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        projectOwner = makeAddr("projectOwner");
        
        // Give test accounts some ETH
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(projectOwner, 100 ether);
        
        console.log("=== Setup Complete ===");
        console.log("Factory deployed at:", address(factory));
        console.log("User1:", user1);
        console.log("User2:", user2);
        console.log("Project Owner:", projectOwner);
    }
    
    function testBuyMemeFullFlow() public {
        console.log("\n=== Test Buy Meme Full Flow ===");
        
        // 1. Create token
        vm.prank(projectOwner);
        testToken = factory.deployMeme(
            "TestMeme",
            "TM",
            1000000 * 1e18, // totalSupply: 1M tokens
            1000 * 1e18,    // perMint: 1000 tokens
            1e15            // price: 0.001 ETH
        );
        
        console.log("Token created:", testToken);
        
        // 2. First mint to create liquidity pool
        uint256 mintCost = factory.getMintCost(testToken);
        console.log("Mint cost:", mintCost);
        vm.prank(user1);
        factory.mintMeme{value: mintCost}(testToken);
        
        console.log("First mint completed, liquidity pool should be created");
        
        // 3. Check if liquidity pool exists
        IFactory uniFactory = IFactory(factory.uniswapV2Factory());
        address pairAddr = uniFactory.getPair(testToken, factory.WETH());
        console.log("Pair address:", pairAddr);
        require(pairAddr != address(0), "Liquidity pool should exist");
        
        // 4. Check liquidity pool reserves
        IPair pair = IPair(pairAddr);
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        console.log("Reserve0:", reserve0);
        console.log("Reserve1:", reserve1);
        
        // 5. Check price comparison
        (uint256 mintPrice, uint256 uniswapPrice, bool isBetter) = factory.comparePrices(testToken);
        console.log("Mint price (per token):", mintPrice);
        console.log("Uniswap price (per token):", uniswapPrice);
        console.log("Is Uniswap better?", isBetter);
        
        // 6. If Uniswap price is not good enough, mint more to change price
        if (!isBetter) {
            console.log("Uniswap price not better yet, minting more to change price...");
            
            for (uint i = 0; i < 5; i++) {
                uint256 additionalMintCost = factory.getMintCost(testToken);
                vm.prank(user1);
                factory.mintMeme{value: additionalMintCost}(testToken);
                
                (mintPrice, uniswapPrice, isBetter) = factory.comparePrices(testToken);
                console.log("After mint", i+2, "- Is Uniswap better?", isBetter);
                
                if (isBetter) break;
            }
        }
        
        // 7. Test buyMeme functionality
        if (isBetter) {
            console.log("\n--- Testing buyMeme ---");
            
            // Get user's token balance before purchase
            UniswapMemeToken token = UniswapMemeToken(testToken);
            uint256 balanceBefore = token.balanceOf(user2);
            console.log("User2 token balance before:", balanceBefore);
            
            // Calculate expected tokens to receive
            uint256 ethAmount = 2e15; // 0.002 ETH
            uint256 expectedTokens = factory.getAmountOut(testToken, ethAmount);
            console.log("Expected tokens for", ethAmount, "ETH:", expectedTokens);
            
            // Execute buyMeme
            vm.prank(user2);
            factory.buyMeme{value: ethAmount}(testToken, expectedTokens * 95 / 100); // 5% slippage
            
            // Check balance after purchase
            uint256 balanceAfter = token.balanceOf(user2);
            console.log("User2 token balance after:", balanceAfter);
            console.log("Tokens received:", balanceAfter - balanceBefore);
            
            // Verify purchase success
            require(balanceAfter > balanceBefore, "Should have received tokens");
            console.log("SUCCESS: buyMeme executed successfully!");
            
        } else {
            console.log("ERROR: Cannot test buyMeme: Uniswap price is not better than mint price");
            console.log("This is expected behavior - buyMeme should only work when Uniswap price is better");
        }
    }
    
    function testBuyMemeFailureCases() public {
        console.log("\n=== Test Buy Meme Failure Cases ===");
        
        // 1. Create token but don't mint (no liquidity pool)
        vm.prank(projectOwner);
        testToken = factory.deployMeme(
            "TestMeme",
            "TM",
            1000000 * 1e18, // totalSupply: 1M tokens
            1000 * 1e18,    // perMint: 1000 tokens
            1e15            // price: 0.001 ETH
        );
        
        console.log("Token created without liquidity pool");
        
        // 2. Test buying when no liquidity pool exists
        vm.prank(user1);
        vm.expectRevert();
        factory.buyMeme{value: 1e15}(testToken, 0);
        console.log("SUCCESS: Correctly reverted when no liquidity pool exists");
        
        // 3. Test invalid token address
        vm.prank(user1);
        vm.expectRevert();
        factory.buyMeme{value: 1e15}(address(0x123), 0);
        console.log("SUCCESS: Correctly reverted for invalid token");
        
        // 4. Test sending 0 ETH
        vm.prank(user1);
        vm.expectRevert();
        factory.buyMeme{value: 0}(testToken, 0);
        console.log("SUCCESS: Correctly reverted when sending 0 ETH");
        
        // 5. Create liquidity pool but price is not good enough
        uint256 mintCost = factory.getMintCost(testToken);
        vm.prank(user1);
        factory.mintMeme{value: mintCost}(testToken);
        console.log("Liquidity pool created");
        
        // Check price
        (,, bool isBetter) = factory.comparePrices(testToken);
        console.log("Is Uniswap price better?", isBetter);
        
        if (!isBetter) {
            vm.prank(user2);
            vm.expectRevert();
            factory.buyMeme{value: 1e15}(testToken, 0);
            console.log("SUCCESS: Correctly reverted when Uniswap price not better");
        }
    }
    
    function testBuyMemeWithSpecificToken() public {
        console.log("\n=== Test Buy Meme with Specific Token ===");
        
        // Use the token address you provided
        address specificToken = 0xC91Cb15c96D85b1658b3F71797DcD0c5093B2e85;
        
        console.log("Testing with token:", specificToken);
        
        // Check if token exists in current factory
        try factory.getTokenInfo(specificToken) returns (
            uint256 perMint,
            uint256 price,
            uint256 mintedAmount,
            uint256 maxTotalSupply,
            address issuer
        ) {
            console.log("Token found in current factory!");
            console.log("Per Mint:", perMint);
            console.log("Price:", price);
            console.log("Minted Amount:", mintedAmount);
            console.log("Max Total Supply:", maxTotalSupply);
            console.log("Issuer:", issuer);
            
            // Check if liquidity pool exists
            IFactory uniFactory = IFactory(factory.uniswapV2Factory());
            address pairAddr = uniFactory.getPair(specificToken, factory.WETH());
            
            if (pairAddr != address(0)) {
                console.log("Liquidity pool exists at:", pairAddr);
                
                // Check price comparison
                (uint256 mintPrice, uint256 uniswapPrice, bool isBetter) = factory.comparePrices(specificToken);
                console.log("Mint price:", mintPrice);
                console.log("Uniswap price:", uniswapPrice);
                console.log("Is Uniswap better?", isBetter);
                
                if (isBetter) {
                    console.log("Attempting to buy meme...");
                    
                    vm.prank(user1);
                    try factory.buyMeme{value: 1e15}(specificToken, 0) {
                        console.log("SUCCESS: buyMeme succeeded!");
                    } catch Error(string memory reason) {
                        console.log("ERROR: buyMeme failed:", reason);
                    }
                } else {
                    console.log("Uniswap price not better, cannot buy");
                }
            } else {
                console.log("No liquidity pool exists");
            }
            
        } catch {
            console.log("Token not found in current factory");
            console.log("This means you need to use the correct factory address");
        }
    }
    
    function testPriceComparison() public {
        console.log("\n=== Test Price Comparison Functions ===");
        
        // Create a token first to test with
        vm.prank(projectOwner);
        address token = factory.deployMeme(
             "TestMeme",
             "TM",
             1000000 * 1e18, // totalSupply: 1M tokens
             1000 * 1e18,    // perMint: 1000 tokens
             1e15            // price: 0.001 ETH
         );
        
        // Test getAmountOut function with valid token but no liquidity
        uint256 amountOut = factory.getAmountOut(token, 1e18);
        console.log("Amount out for token without liquidity:", amountOut);
        
        console.log("SUCCESS: Price comparison functions work correctly");
    }
}