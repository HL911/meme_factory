// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";

// Basic ERC20 interface
interface IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

// UniswapMemeToken interface
interface IUniswapMemeToken {
    function perMint() external view returns (uint256);
    function price() external view returns (uint256);
    function mintedAmount() external view returns (uint256);
    function getMaxTotalSupply() external view returns (uint256);
    function issuer() external view returns (address);
}

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
    function uniswapV2Factory() external view returns (address);
    function uniswapV2Router2() external view returns (address);
    function WETH() external view returns (address);
}

contract OnChainAnalysisTest is Test {
    address constant SPECIFIC_TOKEN = 0xC91Cb15c96D85b1658b3F71797DcD0c5093B2e85;
    
    // 可能的工厂地址（你需要提供实际部署的工厂地址）
    address[] possibleFactories;
    
    function setUp() public {
        // 添加可能的工厂地址
        // 你需要替换为实际部署的工厂地址
        // possibleFactories.push(0x你的工厂地址);
    }
    
    function testAnalyzeTokenOnChain() public {
        console.log("\n=== On-Chain Token Analysis ===");
        console.log("Analyzing token:", SPECIFIC_TOKEN);
        
        // 1. 检查代币是否存在（基本ERC20检查）
        try IERC20(SPECIFIC_TOKEN).name() returns (string memory name) {
            console.log("Token exists! Name:", name);
            
            try IERC20(SPECIFIC_TOKEN).symbol() returns (string memory symbol) {
                console.log("Symbol:", symbol);
            } catch {
                console.log("Failed to get symbol");
            }
            
            try IERC20(SPECIFIC_TOKEN).totalSupply() returns (uint256 totalSupply) {
                console.log("Total Supply:", totalSupply);
            } catch {
                console.log("Failed to get total supply");
            }
            
        } catch {
            console.log("ERROR: Token does not exist or is not a valid ERC20 token");
            return;
        }
        
        // 2. 检查是否是UniswapMemeToken
        try IUniswapMemeToken(SPECIFIC_TOKEN).perMint() returns (uint256 perMint) {
            console.log("This is a UniswapMemeToken!");
            console.log("Per Mint:", perMint);
            
            try IUniswapMemeToken(SPECIFIC_TOKEN).price() returns (uint256 price) {
                console.log("Price:", price);
            } catch {
                console.log("Failed to get price");
            }
            
            try IUniswapMemeToken(SPECIFIC_TOKEN).mintedAmount() returns (uint256 mintedAmount) {
                console.log("Minted Amount:", mintedAmount);
            } catch {
                console.log("Failed to get minted amount");
            }
            
            try IUniswapMemeToken(SPECIFIC_TOKEN).getMaxTotalSupply() returns (uint256 maxSupply) {
                console.log("Max Total Supply:", maxSupply);
            } catch {
                console.log("Failed to get max total supply");
            }
            
            try IUniswapMemeToken(SPECIFIC_TOKEN).issuer() returns (address issuer) {
                console.log("Issuer:", issuer);
            } catch {
                console.log("Failed to get issuer");
            }
            
        } catch {
            console.log("This is not a UniswapMemeToken or has different interface");
        }
    }
    
    function testFindCorrectFactory() public {
        console.log("\n=== Find Correct Factory ===");
        
        // 如果你有可能的工厂地址，在这里测试
        if (possibleFactories.length == 0) {
            console.log("No factory addresses provided to test");
            console.log("Please add your deployed factory address to possibleFactories array");
            return;
        }
        
        for (uint i = 0; i < possibleFactories.length; i++) {
            address factoryAddr = possibleFactories[i];
            console.log("Testing factory:", factoryAddr);
            
            try IUniswapMemeFactory(factoryAddr).tokenToIssuer(SPECIFIC_TOKEN) returns (address issuer) {
                if (issuer != address(0)) {
                    console.log("FOUND! Token is registered in this factory");
                    console.log("Issuer:", issuer);
                    
                    // 获取详细信息
                    try IUniswapMemeFactory(factoryAddr).getTokenInfo(SPECIFIC_TOKEN) returns (
                        uint256 perMint,
                        uint256 price,
                        uint256 mintedAmount,
                        uint256 maxTotalSupply,
                        address tokenIssuer
                    ) {
                        console.log("Token Info from Factory:");
                        console.log("  Per Mint:", perMint);
                        console.log("  Price:", price);
                        console.log("  Minted Amount:", mintedAmount);
                        console.log("  Max Total Supply:", maxTotalSupply);
                        console.log("  Issuer:", tokenIssuer);
                        
                        // 检查是否售罄
                        if (mintedAmount + perMint > maxTotalSupply) {
                            console.log("WARNING: Token is SOLD OUT!");
                        } else {
                            console.log("Token can still be minted");
                        }
                    } catch {
                        console.log("Failed to get token info from factory");
                    }
                    
                    return;
                }
            } catch {
                console.log("Factory call failed or token not found");
            }
        }
        
        console.log("Token not found in any provided factory");
    }
    
    function testManualFactoryCheck() public {
        console.log("\n=== Manual Factory Check ===");
        console.log("You need to provide the actual factory address that deployed this token");
        console.log("Token address:", SPECIFIC_TOKEN);
        
        // 这里你需要手动提供正确的工厂地址
        // address correctFactory = 0x你的工厂地址;
        // 然后取消注释下面的代码进行测试
        
        /*
        console.log("Testing with factory:", correctFactory);
        
        IUniswapMemeFactory factory = IUniswapMemeFactory(correctFactory);
        
        try factory.tokenToIssuer(SPECIFIC_TOKEN) returns (address issuer) {
            if (issuer != address(0)) {
                console.log("Token found! Issuer:", issuer);
                
                // 尝试获取mint cost
                try factory.getMintCost(SPECIFIC_TOKEN) returns (uint256 cost) {
                    console.log("Mint cost:", cost);
                    
                    // 尝试mint（需要足够的ETH）
                    vm.deal(address(this), 10 ether);
                    
                    try factory.mintMeme{value: cost}(SPECIFIC_TOKEN) {
                        console.log("SUCCESS: mintMeme worked!");
                    } catch Error(string memory reason) {
                        console.log("mintMeme failed:", reason);
                    } catch (bytes memory lowLevelData) {
                        console.log("mintMeme failed with low-level error:");
                        console.logBytes(lowLevelData);
                    }
                    
                } catch {
                    console.log("Failed to get mint cost");
                }
            } else {
                console.log("Token not found in this factory");
            }
        } catch {
            console.log("Failed to check token in factory");
        }
        */
    }
    
    function testCheckCodeAtAddress() public view {
        console.log("\n=== Check Code at Address ===");
        
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(SPECIFIC_TOKEN)
        }
        
        console.log("Code size at token address:", codeSize);
        
        if (codeSize == 0) {
            console.log("ERROR: No contract deployed at this address!");
        } else {
            console.log("Contract exists at this address");
        }
    }
}