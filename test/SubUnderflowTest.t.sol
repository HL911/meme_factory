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
}

// Interface for Factory
interface IFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

// Interface for Pair
interface IPair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

contract SubUnderflowTest is Test {
    UniswapMemeFactory factory;
    address issuer = address(0x1);
    address buyer1 = address(0x2);
    address projectOwner = address(0x3);
    
    // Token parameters
    string constant TOKEN_NAME = "TestMeme";
    string constant TOKEN_SYMBOL = "TM";
    uint256 constant TOTAL_SUPPLY = 1000000; // 1M tokens
    uint256 constant PER_MINT = 1000; // 1K tokens per mint
    uint256 constant PRICE = 1000000000000000; // 0.001 ETH
    
    function setUp() public {
        // Give test accounts some ETH
        vm.deal(issuer, 100 ether);
        vm.deal(buyer1, 100 ether);
        vm.deal(projectOwner, 100 ether);
        
        // Deploy factory
        vm.prank(projectOwner);
        factory = new UniswapMemeFactory();
    }
    
    function testSubUnderflowScenario() public {
        console.log("\n=== Test ds-math-sub-underflow Scenario ===");
        
        // 1. Deploy token and mint some to create liquidity
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        
        // 2. Mint once to create initial liquidity
        vm.prank(buyer1);
        factory.mintMeme{value: factory.getMintCost(tokenAddr)}(tokenAddr);
        
        // 3. Get the pair and check reserves
        UniswapMemeToken token = UniswapMemeToken(tokenAddr);
        IFactory uniFactory = IFactory(factory.uniswapV2Factory());
        address pairAddress = uniFactory.getPair(tokenAddr, factory.WETH());
        IPair pair = IPair(pairAddress);
        
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        console.log("Reserve0:", reserve0);
        console.log("Reserve1:", reserve1);
        
        address token0 = pair.token0();
        uint256 tokenReserve = token0 == tokenAddr ? reserve0 : reserve1;
        
        // 4. Try to buy more tokens than available in the pool
        // This should trigger ds-math-sub-underflow
        IRouter router = IRouter(factory.uniswapV2Router2());
        
        address[] memory path = new address[](2);
        path[0] = factory.WETH();
        path[1] = tokenAddr;
        
        // Try to get more tokens than available (this will fail)
        uint256 excessiveAmount = tokenReserve + 1; // More than available
        
        console.log("Trying to get tokens:", excessiveAmount);
        console.log("Available tokens:", tokenReserve);
        
        vm.expectRevert("ds-math-sub-underflow");
        vm.prank(buyer1);
        router.swapETHForExactTokens{value: 10 ether}(
            excessiveAmount, // More tokens than available
            path,
            buyer1,
            block.timestamp + 300
        );
        
        console.log("SUCCESS: Correctly caught ds-math-sub-underflow error");
    }
    
    function testCorrectSwapAmount() public {
        console.log("\n=== Test Correct Swap Amount ===");
        
        // 1. Deploy token and mint some to create liquidity
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        
        // 2. Mint once to create initial liquidity
        vm.prank(buyer1);
        factory.mintMeme{value: factory.getMintCost(tokenAddr)}(tokenAddr);
        
        // 3. Check current liquidity
        IFactory uniswapFactory = IFactory(factory.uniswapV2Factory());
        address pairAddr = uniswapFactory.getPair(tokenAddr, factory.WETH());
        
        IPair pair = IPair(pairAddr);
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        
        address token0 = pair.token0();
        uint256 tokenReserve = token0 == tokenAddr ? reserve0 : reserve1;
        uint256 wethReserve = token0 == tokenAddr ? reserve1 : reserve0;
        
        console.log("Token reserve:", tokenReserve);
        console.log("WETH reserve:", wethReserve);
        
        // 4. Try to buy a reasonable amount (50% of available tokens)
        IRouter router = IRouter(factory.uniswapV2Router2());
        
        address[] memory path = new address[](2);
        path[0] = factory.WETH();
        path[1] = tokenAddr;
        
        uint256 reasonableAmount = tokenReserve / 2; // 50% of available tokens
        
        console.log("Trying to get tokens:", reasonableAmount);
        
        // Get required ETH amount
        uint256[] memory amountsIn = router.getAmountsIn(reasonableAmount, path);
        uint256 requiredETH = amountsIn[0];
        
        console.log("Required ETH:", requiredETH);
        
        // Execute swap
        vm.prank(buyer1);
        uint256[] memory amounts = router.swapETHForExactTokens{value: requiredETH * 110 / 100}( // 10% slippage
            reasonableAmount,
            path,
            buyer1,
            block.timestamp + 300
        );
        
        console.log("ETH used:", amounts[0]);
        console.log("Tokens received:", amounts[1]);
        console.log("SUCCESS: Swap completed without underflow");
    }
    
    function testGetAmountInEdgeCase() public {
        console.log("\n=== Test getAmountIn Edge Case ===");
        
        // Test the specific function that causes the underflow
        IRouter router = IRouter(factory.uniswapV2Router2());
        
        uint256 reserveIn = 1000;
        uint256 reserveOut = 500;
        uint256 amountOut = 600; // More than reserveOut!
        
        console.log("Reserve In:", reserveIn);
        console.log("Reserve Out:", reserveOut);
        console.log("Amount Out (excessive):", amountOut);
        
        // This should fail with ds-math-sub-underflow
        vm.expectRevert("ds-math-sub-underflow");
        router.getAmountIn(amountOut, reserveIn, reserveOut);
        
        console.log("SUCCESS: getAmountIn correctly failed with underflow");
        
        // Now test with a valid amount
        uint256 validAmountOut = 400; // Less than reserveOut
        console.log("Amount Out (valid):", validAmountOut);
        
        uint256 amountIn = router.getAmountIn(validAmountOut, reserveIn, reserveOut);
        console.log("Required Amount In:", amountIn);
        console.log("SUCCESS: getAmountIn worked with valid amount");
    }
}