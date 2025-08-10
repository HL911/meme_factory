// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/UniswapMemeFactory.sol";
import "../src/UniswapMemeToken.sol";

// Interface for Router to avoid version conflicts
interface IRouter {
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    
    function getAmountsIn(uint amountOut, address[] calldata path)
        external
        view
        returns (uint[] memory amounts);
        
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        external
        pure
        returns (uint amountIn);
        
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

// Interface for Factory
interface IFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

// Interface for Pair
interface IPair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

contract SpecificTokenTest is Test {
    UniswapMemeFactory factory;
    address constant SPECIFIC_TOKEN = 0xC91Cb15c96D85b1658b3F71797DcD0c5093B2e85;
    
    address buyer1 = address(0x2);
    address projectOwner = address(0x3);
    
    function setUp() public {
        // Give test accounts some ETH
        vm.deal(buyer1, 100 ether);
        vm.deal(projectOwner, 100 ether);
        
        // Deploy factory
        vm.prank(projectOwner);
        factory = new UniswapMemeFactory();
    }
    
    function testSpecificTokenMintMeme() public {
        console.log("\n=== Test Specific Token mintMeme ===");
        console.log("Token Address:", SPECIFIC_TOKEN);
        
        // 1. Check if token exists and get its info
        try factory.getTokenInfo(SPECIFIC_TOKEN) returns (
            uint256 perMint,
            uint256 price,
            uint256 mintedAmount,
            uint256 maxTotalSupply,
            address issuer
        ) {
            console.log("Token Info:");
            console.log("  Per Mint:", perMint);
            console.log("  Price:", price);
            console.log("  Minted Amount:", mintedAmount);
            console.log("  Max Total Supply:", maxTotalSupply);
            console.log("  Issuer:", issuer);
            
            // 2. Check if token is sold out
            uint256 remainingSupply = maxTotalSupply - mintedAmount;
            console.log("  Remaining Supply:", remainingSupply);
            
            if (remainingSupply < perMint) {
                console.log("ERROR: Token is sold out!");
                return;
            }
            
            // 3. Check current liquidity pool status
            IFactory uniFactory = IFactory(factory.uniswapV2Factory());
            address pairAddress = uniFactory.getPair(SPECIFIC_TOKEN, factory.WETH());
            
            if (pairAddress != address(0)) {
                console.log("Liquidity Pool exists at:", pairAddress);
                
                IPair pair = IPair(pairAddress);
                (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
                
                address token0 = pair.token0();
                uint256 tokenReserve = token0 == SPECIFIC_TOKEN ? reserve0 : reserve1;
                uint256 wethReserve = token0 == SPECIFIC_TOKEN ? reserve1 : reserve0;
                
                console.log("Current Reserves:");
                console.log("  Token Reserve:", tokenReserve);
                console.log("  WETH Reserve:", wethReserve);
                
                // 4. Check if the liquidity addition would cause underflow
                uint256 liquidityTokens = perMint * 5 / 100; // 5% for liquidity
                uint256 projectFee = price / 20; // 5% of price
                
                console.log("Planned Liquidity Addition:");
                console.log("  Liquidity Tokens:", liquidityTokens);
                console.log("  Project Fee (ETH):", projectFee);
                
                // Check if adding liquidity would cause issues
                if (wethReserve > 0 && tokenReserve > 0) {
                    // Calculate expected token amount based on current ratio
                    uint256 expectedTokenAmount = (projectFee * tokenReserve) / wethReserve;
                    console.log("  Expected Token Amount for Ratio:", expectedTokenAmount);
                    
                    if (expectedTokenAmount > liquidityTokens) {
                        console.log("WARNING: Liquidity tokens insufficient for current ratio!");
                        console.log("  Need:", expectedTokenAmount);
                        console.log("  Have:", liquidityTokens);
                    }
                }
            } else {
                console.log("No liquidity pool exists yet");
            }
            
            // 5. Try to mint and catch the specific error
            uint256 mintCost = factory.getMintCost(SPECIFIC_TOKEN);
            console.log("Mint Cost:", mintCost);
            
            vm.prank(buyer1);
            try factory.mintMeme{value: mintCost}(SPECIFIC_TOKEN) {
                console.log("SUCCESS: mintMeme completed successfully");
            } catch Error(string memory reason) {
                console.log("ERROR: mintMeme failed with reason:", reason);
            } catch (bytes memory lowLevelData) {
                console.log("ERROR: mintMeme failed with low-level error");
                console.logBytes(lowLevelData);
            }
            
        } catch Error(string memory reason) {
            console.log("ERROR: Token does not exist or invalid:", reason);
        }
    }
    
    function testAnalyzeLiquidityAddition() public {
        console.log("\n=== Analyze Liquidity Addition Process ===");
        
        // Get token info
        try factory.getTokenInfo(SPECIFIC_TOKEN) returns (
            uint256 perMint,
            uint256 price,
            uint256 mintedAmount,
            uint256 maxTotalSupply,
            address issuer
        ) {
            console.log("Analyzing liquidity addition for token:", SPECIFIC_TOKEN);
            
            // Check current pool state
            IFactory uniFactory = IFactory(factory.uniswapV2Factory());
            address pairAddress = uniFactory.getPair(SPECIFIC_TOKEN, factory.WETH());
            
            if (pairAddress != address(0)) {
                IPair pair = IPair(pairAddress);
                (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
                
                address token0 = pair.token0();
                uint256 tokenReserve = token0 == SPECIFIC_TOKEN ? reserve0 : reserve1;
                uint256 wethReserve = token0 == SPECIFIC_TOKEN ? reserve1 : reserve0;
                
                console.log("Current Pool State:");
                console.log("  Token Reserve:", tokenReserve);
                console.log("  WETH Reserve:", wethReserve);
                
                // Simulate the liquidity addition parameters
                uint256 liquidityTokens = perMint * 5 / 100;
                uint256 projectFee = price / 20;
                
                console.log("Liquidity Addition Parameters:");
                console.log("  Liquidity Tokens:", liquidityTokens);
                console.log("  Project Fee (ETH):", projectFee);
                
                // Calculate minimum amounts with 5% slippage
                uint256 minTokenAmount = liquidityTokens * 95 / 100;
                uint256 minETHAmount = projectFee * 95 / 100;
                
                console.log("Minimum Amounts (5% slippage):");
                console.log("  Min Token Amount:", minTokenAmount);
                console.log("  Min ETH Amount:", minETHAmount);
                
                // Try to simulate addLiquidityETH call
                IRouter router = IRouter(factory.uniswapV2Router2());
                
                // First approve tokens (simulate)
                console.log("Simulating addLiquidityETH call...");
                
                try router.addLiquidityETH{value: projectFee}(
                    SPECIFIC_TOKEN,
                    liquidityTokens,
                    minTokenAmount,
                    minETHAmount,
                    address(this),
                    block.timestamp + 300
                ) {
                    console.log("SUCCESS: addLiquidityETH simulation passed");
                } catch Error(string memory reason) {
                    console.log("ERROR in addLiquidityETH:", reason);
                } catch (bytes memory lowLevelData) {
                    console.log("LOW-LEVEL ERROR in addLiquidityETH:");
                    console.logBytes(lowLevelData);
                }
            }
        } catch {
            console.log("Failed to get token info");
        }
    }
    
    function testDirectRouterCall() public {
        console.log("\n=== Test Direct Router Calls ===");
        
        IRouter router = IRouter(factory.uniswapV2Router2());
        
        // Test getAmountIn with problematic values
        console.log("Testing getAmountIn function directly...");
        
        // These values might cause underflow
        uint256 reserveIn = 1000;
        uint256 reserveOut = 500;
        uint256 amountOut = 600; // More than reserveOut
        
        console.log("Test Case 1 - Should cause underflow:");
        console.log("  Reserve In:", reserveIn);
        console.log("  Reserve Out:", reserveOut);
        console.log("  Amount Out:", amountOut);
        
        try router.getAmountIn(amountOut, reserveIn, reserveOut) returns (uint256 amountIn) {
            console.log("  Result:", amountIn);
        } catch Error(string memory reason) {
            console.log("  ERROR:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("  LOW-LEVEL ERROR:");
            console.logBytes(lowLevelData);
        }
    }
}