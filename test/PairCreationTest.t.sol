// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/UniswapMemeFactory.sol";

interface IPair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

contract PairCreationTest is Test {
    UniswapMemeFactory factory;
    address issuer = address(0x1);
    address buyer = address(0x2);
    
    function setUp() public {
        vm.deal(issuer, 10 ether);
        vm.deal(buyer, 10 ether);
        
        factory = new UniswapMemeFactory();
        
        console.log("=== Test Environment Setup ===");
        console.log("Current block number:", block.number);
        console.log("Factory contract address:", address(factory));
        console.log("Uniswap V2 Factory:", address(factory.uniswapV2FactoryContract()));
        console.log("Uniswap V2 Router:", address(factory.uniswapV2Router2Contract()));
        console.log("WETH address:", factory.WETH());
    }
    
    function testDirectPairCreation() public {
        console.log("\n=== Test Direct Pair Creation ===");
        
        // 1. Deploy a token first
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme(
            "TestToken",
            "TT",
            10000,
            1000,
            0.001 ether
        );
        
        console.log("Token deployed:", tokenAddr);
        
        // 2. Try to create pair directly
        IUniswapV2Factory uniswapFactory = factory.uniswapV2FactoryContract();
        address weth = factory.WETH();
        
        console.log("Before createPair - checking existing pair:");
        address existingPair = uniswapFactory.getPair(tokenAddr, weth);
        console.log("Existing pair:", existingPair);
        
        if (existingPair == address(0)) {
            console.log("No existing pair, creating new one...");
            
            try uniswapFactory.createPair(tokenAddr, weth) returns (address newPair) {
                console.log("SUCCESS: Pair created at:", newPair);
                
                // Verify the pair
                if (newPair != address(0)) {
                    IPair pair = IPair(newPair);
                    
                    try pair.token0() returns (address token0) {
                        console.log("Pair token0:", token0);
                    } catch {
                        console.log("Failed to get token0");
                    }
                    
                    try pair.token1() returns (address token1) {
                        console.log("Pair token1:", token1);
                    } catch {
                        console.log("Failed to get token1");
                    }
                    
                    // Check reserves (should be 0 initially)
                    try pair.getReserves() returns (uint112 reserve0, uint112 reserve1, uint32 timestamp) {
                        console.log("Reserve0:", reserve0);
                        console.log("Reserve1:", reserve1);
                        console.log("Timestamp:", timestamp);
                    } catch {
                        console.log("Failed to get reserves");
                    }
                }
            } catch Error(string memory reason) {
                console.log("FAILED: createPair failed with reason:", reason);
            } catch {
                console.log("FAILED: createPair failed with unknown error");
            }
        } else {
            console.log("Pair already exists:", existingPair);
        }
    }
    
    function testRouterCompatibility() public {
        console.log("\n=== Test Router Compatibility ===");
        
        // 1. Deploy a token
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme(
            "TestToken",
            "TT", 
            10000,
            1000,
            0.001 ether
        );
        
        // 2. Check if Router can work with this Factory
        IUniswapV2Router02 router = factory.uniswapV2Router2Contract();
        IUniswapV2Factory uniswapFactory = factory.uniswapV2FactoryContract();
        
        console.log("Router address:", address(router));
        console.log("Factory address:", address(uniswapFactory));
        
        // Check if Router's factory matches our factory
        try router.factory() returns (address routerFactory) {
            console.log("Router's factory:", routerFactory);
            console.log("Our factory:", address(uniswapFactory));
            
            if (routerFactory == address(uniswapFactory)) {
                console.log("SUCCESS: Router and Factory are compatible");
            } else {
                console.log("WARNING: Router and Factory mismatch!");
                console.log("This explains why addLiquidityETH fails");
            }
        } catch {
            console.log("Failed to get router's factory");
        }
        
        // Check WETH compatibility
        try router.WETH() returns (address routerWETH) {
            console.log("Router's WETH:", routerWETH);
            console.log("Our WETH:", factory.WETH());
            
            if (routerWETH == factory.WETH()) {
                console.log("SUCCESS: WETH addresses match");
            } else {
                console.log("WARNING: WETH addresses mismatch!");
            }
        } catch {
            console.log("Failed to get router's WETH");
        }
    }
    
    function testFactoryOwnership() public {
        console.log("\n=== Test Factory Ownership and Settings ===");
        
        IUniswapV2Factory uniswapFactory = factory.uniswapV2FactoryContract();
        
        // Check factory settings
        try uniswapFactory.feeTo() returns (address feeTo) {
            console.log("Factory feeTo:", feeTo);
        } catch {
            console.log("Failed to get feeTo or function doesn't exist");
        }
        
        try uniswapFactory.feeToSetter() returns (address feeToSetter) {
            console.log("Factory feeToSetter:", feeToSetter);
        } catch {
            console.log("Failed to get feeToSetter or function doesn't exist");
        }
        
        // Check if we can get allPairsLength
        try uniswapFactory.allPairsLength() returns (uint256 length) {
            console.log("Total pairs in factory:", length);
        } catch {
            console.log("Failed to get allPairsLength or function doesn't exist");
        }
    }
}