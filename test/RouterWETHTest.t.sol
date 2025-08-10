// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";

interface IUniswapV2Router02 {
    function WETH() external pure returns (address);
    function factory() external pure returns (address);
}

contract RouterWETHTest is Test {
    address constant ROUTER = 0xd2268B943Fa81ac0600b753CE1c9C18BC805f89F;
    address constant OUR_WETH = 0x127Abc00C9Fef19a9690f890711670695324c489;
    
    function testRouterWETH() public {
        console.log("=== Testing Router WETH Configuration ===");
        console.log("Router address:", ROUTER);
        console.log("Our WETH address:", OUR_WETH);
        
        // 检查Router配置的WETH地址
        address routerWETH = IUniswapV2Router02(ROUTER).WETH();
        console.log("Router's WETH address:", routerWETH);
        
        if (routerWETH == OUR_WETH) {
            console.log("SUCCESS: WETH addresses match");
        } else {
            console.log("ERROR: WETH addresses do not match");
            
            // 检查Router的WETH是否存在
            uint256 codeSize;
            assembly {
                codeSize := extcodesize(routerWETH)
            }
            console.log("Router's WETH code size:", codeSize);
        }
        
        // 检查Factory地址
        address routerFactory = IUniswapV2Router02(ROUTER).factory();
        console.log("Router's Factory address:", routerFactory);
    }
}