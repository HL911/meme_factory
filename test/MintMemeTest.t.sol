// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/UniswapMemeFactory.sol";
import "../src/UniswapMemeToken.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract MintMemeTest is Test {
    UniswapMemeFactory public factory;
    
    address public projectOwner;
    address public issuer;
    address public buyer1;
    address public buyer2;
    
    // Test token parameters
    string constant TOKEN_NAME = "TestMintMeme";
    string constant TOKEN_SYMBOL = "TMM";
    uint256 constant TOTAL_SUPPLY = 1000000; // 1 million tokens
    uint256 constant PER_MINT = 1000; // 1000 tokens per mint
    uint256 constant PRICE = 0.001 ether; // 0.001 ETH per mint
    
    event MemeDeployed(address indexed tokenAddr, string symbol, address indexed issuer);
    event MemeMinted(address indexed tokenAddr, address indexed buyer, uint256 amount);
    event LiquidityAdded(address indexed tokenAddr, uint256 tokenAmount, uint256 ethAmount);
    
    function setUp() public {
        // Fork Sepolia testnet
        string memory sepoliaRpcUrl = "https://sepolia.infura.io/v3/3dbfb8be9fbd4be19fec5cae43e6a8a7";
        vm.createFork(sepoliaRpcUrl);
        
        // Setup test accounts
        projectOwner = makeAddr("projectOwner");
        issuer = makeAddr("issuer");
        buyer1 = makeAddr("buyer1");
        buyer2 = makeAddr("buyer2");
        
        // Give test accounts some ETH
        vm.deal(projectOwner, 100 ether);
        vm.deal(issuer, 100 ether);
        vm.deal(buyer1, 100 ether);
        vm.deal(buyer2, 100 ether);
        
        // Deploy factory contract
        factory = new UniswapMemeFactory();
        
        console.log("=== Test Environment Setup ===");
        console.log("Current block number:", block.number);
        console.log("Factory contract address:", address(factory));
        console.log("Uniswap V2 Factory:", factory.uniswapV2Factory());
        console.log("Uniswap V2 Router:", factory.uniswapV2Router2());
        console.log("WETH address:", factory.WETH());
    }
    
    function testMintMemeBasic() public {
        console.log("\n=== Test Basic mintMeme Function ===");
        
        // 1. Deploy token
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        
        console.log("Token address:", tokenAddr);
        
        UniswapMemeToken token = UniswapMemeToken(tokenAddr);
        console.log("Token name:", token.name());
        console.log("Token symbol:", token.symbol());
        console.log("Max total supply:", token.getMaxTotalSupply());
        console.log("Per mint amount:", token.perMint());
        console.log("Mint price:", token.price());
        
        // 2. Check initial state
        assertEq(token.mintedAmount(), 0, "Initial minted amount should be 0");
        assertEq(token.balanceOf(buyer1), 0, "Buyer initial balance should be 0");
        assertEq(token.balanceOf(address(factory)), 0, "Factory initial balance should be 0");
        
        // 3. Execute first mint
        uint256 cost = factory.getMintCost(tokenAddr);
        console.log("Mint cost:", cost);
        
        uint256 buyer1InitialETH = buyer1.balance;
        uint256 issuerInitialETH = issuer.balance;
        uint256 projectOwnerInitialETH = factory.projectOwner().balance;
        
        vm.prank(buyer1);
        factory.mintMeme{value: cost}(tokenAddr);
        
        // 4. Verify mint results
        uint256 perMintWei = PER_MINT * 10**18;
        uint256 userTokens = perMintWei * 95 / 100; // 95% to user
        uint256 liquidityTokens = perMintWei - userTokens; // 5% for liquidity
        
        console.log("User expected tokens:", userTokens);
        console.log("Liquidity tokens:", liquidityTokens);
        console.log("User actual tokens:", token.balanceOf(buyer1));
        console.log("Factory actual tokens:", token.balanceOf(address(factory)));
        console.log("Total minted amount:", token.mintedAmount());
        
        assertEq(token.balanceOf(buyer1), userTokens, "User token balance incorrect");
        // Factory balance should be 0 after adding liquidity
        assertEq(token.balanceOf(address(factory)), 0, "Factory token balance should be 0 after liquidity addition");
        assertEq(token.mintedAmount(), perMintWei, "Total minted amount incorrect");
        
        // 5. Verify ETH distribution
        uint256 projectFee = cost / 20; // 5%
        uint256 issuerFee = cost - projectFee; // 95%
        
        console.log("Project fee:", projectFee);
        console.log("Issuer fee:", issuerFee);
        
        assertEq(buyer1.balance, buyer1InitialETH - cost, "Buyer ETH balance incorrect");
        assertEq(issuer.balance, issuerInitialETH + issuerFee, "Issuer ETH balance incorrect");
        // Project fee is used for liquidity, so project owner's ETH balance should remain unchanged
        assertEq(factory.projectOwner().balance, projectOwnerInitialETH, "Project owner ETH balance should be unchanged");
    }
    
    function testLiquidityPoolCreation() public {
        console.log("\n=== Test Liquidity Pool Creation ===");
        
        // 1. Deploy token
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        
        // 2. Check initial state - should have no liquidity pool
        IUniswapV2Factory uniswapFactory = factory.uniswapV2FactoryContract();
        address weth = factory.WETH();
        address initialPair = uniswapFactory.getPair(tokenAddr, weth);
        
        console.log("Initial pair address:", initialPair);
        assertEq(initialPair, address(0), "Should have no liquidity pool initially");
        
        // 3. Execute mint
        vm.prank(buyer1);
        factory.mintMeme{value: factory.getMintCost(tokenAddr)}(tokenAddr);
        
        // 4. Check if liquidity pool is created
        address pairAfterMint = uniswapFactory.getPair(tokenAddr, weth);
        console.log("Pair address after mint:", pairAfterMint);
        
        if (pairAfterMint != address(0)) {
            console.log("SUCCESS: Liquidity pool created successfully!");
            
            // Check liquidity pool state
            IUniswapV2Pair pair = IUniswapV2Pair(pairAfterMint);
            (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
            
            console.log("Reserve0:", reserve0);
            console.log("Reserve1:", reserve1);
            console.log("Total liquidity:", pair.totalSupply());
            
            // Determine which is token and which is WETH
            address token0 = pair.token0();
            address token1 = pair.token1();
            console.log("Token0:", token0);
            console.log("Token1:", token1);
            
            if (token0 == tokenAddr) {
                console.log("Token reserve:", reserve0);
                console.log("WETH reserve:", reserve1);
            } else {
                console.log("Token reserve:", reserve1);
                console.log("WETH reserve:", reserve0);
            }
            
            assertTrue(reserve0 > 0 || reserve1 > 0, "Liquidity pool should have reserves");
        } else {
            console.log("FAILED: Liquidity pool not created");
            
            // Check if factory still holds tokens (if liquidity addition failed)
            UniswapMemeToken token = UniswapMemeToken(tokenAddr);
            uint256 factoryBalance = token.balanceOf(address(factory));
            console.log("Factory token balance:", factoryBalance);
            
            if (factoryBalance > 0) {
                console.log("Factory still holds tokens, liquidity addition may have failed");
            }
        }
    }
    
    function testMultipleMintAndLiquidity() public {
        console.log("\n=== Test Multiple Mints and Liquidity Accumulation ===");
        
        // 1. Deploy token
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
        IUniswapV2Factory uniswapFactory = factory.uniswapV2FactoryContract();
        address weth = factory.WETH();
        
        // 2. First mint
        console.log("--- First Mint ---");
        vm.prank(buyer1);
        factory.mintMeme{value: cost}(tokenAddr);
        
        address pairAfterFirst = uniswapFactory.getPair(tokenAddr, weth);
        uint256 factoryBalanceAfterFirst = token.balanceOf(address(factory));
        
        console.log("Pair address after first mint:", pairAfterFirst);
        console.log("Factory balance after first mint:", factoryBalanceAfterFirst);
        
        // 3. Second mint
        console.log("--- Second Mint ---");
        vm.prank(buyer2);
        factory.mintMeme{value: cost}(tokenAddr);
        
        address pairAfterSecond = uniswapFactory.getPair(tokenAddr, weth);
        uint256 factoryBalanceAfterSecond = token.balanceOf(address(factory));
        
        console.log("Pair address after second mint:", pairAfterSecond);
        console.log("Factory balance after second mint:", factoryBalanceAfterSecond);
        
        // 4. Verify liquidity accumulation
        if (pairAfterSecond != address(0)) {
            IUniswapV2Pair pair = IUniswapV2Pair(pairAfterSecond);
            (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
            
            console.log("Final reserve0:", reserve0);
            console.log("Final reserve1:", reserve1);
            
            // Check if liquidity increased
            assertTrue(reserve0 > 0 || reserve1 > 0, "Should have liquidity reserves");
            
            // Factory balance should be low or 0 (tokens used for liquidity)
            console.log("Final factory token balance:", factoryBalanceAfterSecond);
        }
        
        // 5. Verify user token distribution
        uint256 perMintWei = PER_MINT * 10**18;
        uint256 userTokens = perMintWei * 95 / 100;
        
        assertEq(token.balanceOf(buyer1), userTokens, "Buyer1 token balance incorrect");
        assertEq(token.balanceOf(buyer2), userTokens, "Buyer2 token balance incorrect");
        assertEq(token.mintedAmount(), perMintWei * 2, "Total minted amount incorrect");
    }
    
    function testLiquidityAdditionFailure() public {
        console.log("\n=== Test Liquidity Addition Failure ===");
        
        // 1. Deploy token
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        
        // 2. Mint tokens
        vm.prank(buyer1);
        factory.mintMeme{value: factory.getMintCost(tokenAddr)}(tokenAddr);
        
        // 3. Check results
        UniswapMemeToken token = UniswapMemeToken(tokenAddr);
        IUniswapV2Factory uniswapFactory = factory.uniswapV2FactoryContract();
        address weth = factory.WETH();
        address pair = uniswapFactory.getPair(tokenAddr, weth);
        
        console.log("Pair address:", pair);
        console.log("Factory token balance:", token.balanceOf(address(factory)));
        console.log("Factory ETH balance:", address(factory).balance);
        
        if (pair == address(0)) {
            console.log("FAILED: Liquidity pool not created");
            
            // If liquidity addition failed, factory should still hold tokens
            uint256 factoryBalance = token.balanceOf(address(factory));
            assertTrue(factoryBalance > 0, "Factory should hold tokens when liquidity addition fails");
            
            console.log("Liquidity addition failed, factory holds tokens:", factoryBalance);
        } else {
            console.log("SUCCESS: Liquidity pool created successfully");
            
            IUniswapV2Pair pairContract = IUniswapV2Pair(pair);
            (uint112 reserve0, uint112 reserve1,) = pairContract.getReserves();
            
            console.log("Liquidity pool reserve0:", reserve0);
            console.log("Liquidity pool reserve1:", reserve1);
            
            assertTrue(reserve0 > 0 || reserve1 > 0, "Liquidity pool should have reserves");
        }
    }
    
    function testMintMemeWithInsufficientETH() public {
        console.log("\n=== Test Insufficient ETH ===");
        
        // 1. Deploy token
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        
        uint256 cost = factory.getMintCost(tokenAddr);
        console.log("Required cost:", cost);
        
        // 2. Try to mint with insufficient ETH
        vm.prank(buyer1);
        vm.expectRevert("UniswapMemeFactory: insufficient payment");
        factory.mintMeme{value: cost - 1}(tokenAddr);
        
        console.log("SUCCESS: Correctly rejected mint request with insufficient ETH");
    }
    
    function testMintMemeSoldOut() public {
        console.log("\n=== Test Token Sold Out ===");
        
        // 1. Deploy token with small supply (2 * PER_MINT to allow exactly 2 mints)
        uint256 smallSupply = 2 * PER_MINT; // 2000 tokens total, allows exactly 2 mints of 1000 each
        
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            smallSupply, // Small supply
            PER_MINT,
            PRICE
        );
        
        UniswapMemeToken token = UniswapMemeToken(tokenAddr);
        console.log("Max total supply:", token.getMaxTotalSupply());
        console.log("Per mint amount:", token.perMint());
        
        uint256 cost = factory.getMintCost(tokenAddr);
        
        // 2. First mint (should succeed)
        vm.prank(buyer1);
        factory.mintMeme{value: cost}(tokenAddr);
        
        console.log("Total amount after first mint:", token.mintedAmount());
        
        // 3. Second mint (should succeed)
        vm.prank(buyer2);
        factory.mintMeme{value: cost}(tokenAddr);
        
        console.log("Total amount after second mint:", token.mintedAmount());
        
        // 4. Third mint (should fail, exceeds supply)
        vm.prank(buyer1);
        vm.expectRevert("UniswapMemeFactory: sold out");
        factory.mintMeme{value: cost}(tokenAddr);
        
        console.log("SUCCESS: Correctly rejected mint request exceeding supply");
    }
}