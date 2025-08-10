// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";

// Factory interface
interface IUniswapMemeFactory {
    function tokenToIssuer(address token) external view returns (address);
    function getTokenInfo(address tokenAddr) external view returns (
        uint256 perMint,
        uint256 price,
        uint256 mintedAmount,
        uint256 maxTotalSupply,
        address issuer
    );
    function getMintCost(address tokenAddr) external view returns (uint256);
    function mintMeme(address tokenAddr) external payable;
}

contract FindFactoryTest is Test {
    address constant SPECIFIC_TOKEN = 0xC91Cb15c96D85b1658b3F71797DcD0c5093B2e85;
    
    function testWithYourFactoryAddress() public {
        console.log("\n=== Test with Your Factory Address ===");
        console.log("Token:", SPECIFIC_TOKEN);
        
        // Please replace with your actual factory contract address
        // address yourFactory = 0xYourFactoryAddress;
        
        console.log("Please provide your factory contract address!");
        console.log("Then uncomment the code below and replace factory address");
        
        /*
        console.log("Testing with your factory:", yourFactory);
        
        IUniswapMemeFactory factory = IUniswapMemeFactory(yourFactory);
        
        // Check if token exists in this factory
        try factory.tokenToIssuer(SPECIFIC_TOKEN) returns (address issuer) {
            if (issuer != address(0)) {
                console.log("SUCCESS: Token found in this factory!");
                console.log("Issuer:", issuer);
                
                // Get token info
                try factory.getTokenInfo(SPECIFIC_TOKEN) returns (
                    uint256 perMint,
                    uint256 price,
                    uint256 mintedAmount,
                    uint256 maxTotalSupply,
                    address tokenIssuer
                ) {
                    console.log("Token Info:");
                    console.log("  Per Mint:", perMint);
                    console.log("  Price:", price);
                    console.log("  Minted Amount:", mintedAmount);
                    console.log("  Max Total Supply:", maxTotalSupply);
                    
                    // Check if sold out
                    if (mintedAmount + perMint > maxTotalSupply) {
                        console.log("ERROR: Token sold out!");
                        return;
                    }
                    
                    console.log("SUCCESS: Token can be minted");
                    
                    // Get mint cost
                    uint256 mintCost = factory.getMintCost(SPECIFIC_TOKEN);
                    console.log("Mint Cost:", mintCost, "wei");
                    
                    // Give test account some ETH
                    vm.deal(address(this), 10 ether);
                    
                    console.log("Attempting to mint token...");
                    
                    // Try to mint
                    try factory.mintMeme{value: mintCost}(SPECIFIC_TOKEN) {
                        console.log("SUCCESS: mintMeme executed successfully!");
                    } catch Error(string memory reason) {
                        console.log("ERROR: mintMeme failed, reason:", reason);
                        
                        if (keccak256(bytes(reason)) == keccak256(bytes("ds-math-sub-underflow"))) {
                            console.log("This is ds-math-sub-underflow error");
                            console.log("Possible causes:");
                            console.log("1. Insufficient liquidity pool reserves");
                            console.log("2. Calculation issues when adding liquidity");
                            console.log("3. Math underflow in Router contract");
                        }
                    } catch (bytes memory lowLevelData) {
                        console.log("ERROR: mintMeme failed, low level error:");
                        console.logBytes(lowLevelData);
                    }
                    
                } catch {
                    console.log("ERROR: Cannot get token info");
                }
                
            } else {
                console.log("ERROR: Token not found in this factory");
            }
        } catch {
            console.log("ERROR: Factory call failed");
        }
        */
    }
    
    function testInstructions() public view {
        console.log("\n=== Instructions ===");
        console.log("1. Find the factory contract address used when deploying this token");
        console.log("2. Replace the factory address in testWithYourFactoryAddress() function");
        console.log("3. Uncomment the relevant code");
        console.log("4. Re-run the test");
        console.log("");
        console.log("Token Address:", SPECIFIC_TOKEN);
        console.log("Token Name: qq");
        console.log("Token Symbol: qq");
        console.log("Issuer: 0x8f5d0e2aaC23445B2AE2B5b47624899540DFA109");
        console.log("");
        console.log("If you don't remember the factory address, check:");
        console.log("1. Deployment transaction logs");
        console.log("2. Your deployment scripts");
        console.log("3. Transaction records in blockchain explorer");
    }
}