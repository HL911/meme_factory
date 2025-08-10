// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

interface IFactoryTest {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function initCodeHash() external view returns (bytes32);
    function INIT_CODE_PAIR_HASH() external view returns (bytes32);
    function pairCodeHash() external view returns (bytes32);
}

contract FactoryInterfaceTest is Test {
    
    function testCurrentFactory() public {
        console.log("=== Testing Current Factory Interface ===");
        
        address factoryAddr = 0xA9427c01a19d28296b4878d3860CA86E4B117d7C;
        IFactoryTest factory = IFactoryTest(factoryAddr);
        
        console.log("Factory address:", factoryAddr);
        
        // Test initCodeHash
        try factory.initCodeHash() returns (bytes32 hash) {
            console.log("initCodeHash exists, value:");
            console.logBytes32(hash);
        } catch {
            console.log("initCodeHash function does not exist or failed");
        }
        
        // Test INIT_CODE_PAIR_HASH
        try factory.INIT_CODE_PAIR_HASH() returns (bytes32 hash) {
            console.log("INIT_CODE_PAIR_HASH exists, value:");
            console.logBytes32(hash);
        } catch {
            console.log("INIT_CODE_PAIR_HASH function does not exist or failed");
        }
        
        // Test pairCodeHash
        try factory.pairCodeHash() returns (bytes32 hash) {
            console.log("pairCodeHash exists, value:");
            console.logBytes32(hash);
        } catch {
            console.log("pairCodeHash function does not exist or failed");
        }
        
        // Test basic getPair functionality
        address token1 = 0x20c85d4EeD7152B396c01bCD3Ad0Daaa2faDbe2B; // WETH
        address token2 = 0x1234567890123456789012345678901234567890; // Random address
        
        try factory.getPair(token1, token2) returns (address pair) {
            console.log("getPair works, result:", pair);
        } catch {
            console.log("getPair failed");
        }
    }
    
    function testAlternativeFactory() public {
        console.log("\n=== Testing Alternative Factory Interface ===");
        
        address factoryAddr = 0xF62c03E08ada871A0bEb309762E260a7a6a880E6;
        IFactoryTest factory = IFactoryTest(factoryAddr);
        
        console.log("Factory address:", factoryAddr);
        
        // Test initCodeHash
        try factory.initCodeHash() returns (bytes32 hash) {
            console.log("initCodeHash exists, value:");
            console.logBytes32(hash);
        } catch {
            console.log("initCodeHash function does not exist or failed");
        }
        
        // Test INIT_CODE_PAIR_HASH
        try factory.INIT_CODE_PAIR_HASH() returns (bytes32 hash) {
            console.log("INIT_CODE_PAIR_HASH exists, value:");
            console.logBytes32(hash);
        } catch {
            console.log("INIT_CODE_PAIR_HASH function does not exist or failed");
        }
        
        // Test pairCodeHash
        try factory.pairCodeHash() returns (bytes32 hash) {
            console.log("pairCodeHash exists, value:");
            console.logBytes32(hash);
        } catch {
            console.log("pairCodeHash function does not exist or failed");
        }
        
        // Test basic getPair functionality
        address token1 = 0x20c85d4EeD7152B396c01bCD3Ad0Daaa2faDbe2B; // WETH
        address token2 = 0x1234567890123456789012345678901234567890; // Random address
        
        try factory.getPair(token1, token2) returns (address pair) {
            console.log("getPair works, result:", pair);
        } catch {
            console.log("getPair failed");
        }
    }
}