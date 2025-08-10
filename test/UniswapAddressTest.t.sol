// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

contract UniswapAddressTest is Test {
    
    function testCurrentAddresses() public {
        console.log("=== Testing Current Addresses ===");
        
        // Current addresses in contract
        address currentFactory = 0xA9427c01a19d28296b4878d3860CA86E4B117d7C;
        address currentRouter = 0x5b75396BA3B5893C1fAEF8DA44dC02c70a0517eC;
        address currentWETH = 0x20c85d4EeD7152B396c01bCD3Ad0Daaa2faDbe2B;
        
        console.log("Current Factory:", currentFactory);
        console.log("Current Router:", currentRouter);
        console.log("Current WETH:", currentWETH);
        
        // Check if contracts exist
        uint256 factoryCodeSize;
        uint256 routerCodeSize;
        uint256 wethCodeSize;
        
        assembly {
            factoryCodeSize := extcodesize(currentFactory)
            routerCodeSize := extcodesize(currentRouter)
            wethCodeSize := extcodesize(currentWETH)
        }
        
        console.log("Factory code size:", factoryCodeSize);
        console.log("Router code size:", routerCodeSize);
        console.log("WETH code size:", wethCodeSize);
        
        if (factoryCodeSize > 0) {
            console.log("SUCCESS: Factory contract exists");
        } else {
            console.log("FAILED: Factory contract does not exist");
        }
        
        if (routerCodeSize > 0) {
            console.log("SUCCESS: Router contract exists");
        } else {
            console.log("FAILED: Router contract does not exist");
        }
        
        if (wethCodeSize > 0) {
            console.log("SUCCESS: WETH contract exists");
        } else {
            console.log("FAILED: WETH contract does not exist");
        }
    }
    
    function testAlternativeAddresses() public {
        console.log("\n=== Testing Alternative Addresses ===");
        
        // Alternative addresses from web search
        address altFactory = 0xF62c03E08ada871A0bEb309762E260a7a6a880E6;
        address altRouter = 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3;
        
        console.log("Alternative Factory:", altFactory);
        console.log("Alternative Router:", altRouter);
        
        // Check if contracts exist
        uint256 altFactoryCodeSize;
        uint256 altRouterCodeSize;
        
        assembly {
            altFactoryCodeSize := extcodesize(altFactory)
            altRouterCodeSize := extcodesize(altRouter)
        }
        
        console.log("Alternative Factory code size:", altFactoryCodeSize);
        console.log("Alternative Router code size:", altRouterCodeSize);
        
        if (altFactoryCodeSize > 0) {
            console.log("SUCCESS: Alternative Factory contract exists");
        } else {
            console.log("FAILED: Alternative Factory contract does not exist");
        }
        
        if (altRouterCodeSize > 0) {
            console.log("SUCCESS: Alternative Router contract exists");
        } else {
            console.log("FAILED: Alternative Router contract does not exist");
        }
    }
    
    function testMainnetAddresses() public {
        console.log("\n=== Testing Mainnet Addresses (for reference) ===");
        
        // Mainnet addresses
        address mainnetFactory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
        address mainnetRouter = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
        
        console.log("Mainnet Factory:", mainnetFactory);
        console.log("Mainnet Router:", mainnetRouter);
        
        // Check if contracts exist (should not exist on Sepolia)
        uint256 mainnetFactoryCodeSize;
        uint256 mainnetRouterCodeSize;
        
        assembly {
            mainnetFactoryCodeSize := extcodesize(mainnetFactory)
            mainnetRouterCodeSize := extcodesize(mainnetRouter)
        }
        
        console.log("Mainnet Factory code size:", mainnetFactoryCodeSize);
        console.log("Mainnet Router code size:", mainnetRouterCodeSize);
        
        if (mainnetFactoryCodeSize > 0) {
            console.log("UNEXPECTED: Mainnet Factory contract exists on Sepolia");
        } else {
            console.log("EXPECTED: Mainnet Factory contract does not exist on Sepolia");
        }
        
        if (mainnetRouterCodeSize > 0) {
            console.log("UNEXPECTED: Mainnet Router contract exists on Sepolia");
        } else {
            console.log("EXPECTED: Mainnet Router contract does not exist on Sepolia");
        }
    }
}