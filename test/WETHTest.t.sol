// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
}

contract WETHTest is Test {
    address constant CURRENT_WETH = 0x127Abc00C9Fef19a9690f890711670695324c489;
    
    function testCurrentWETH() public {
        console.log("=== Testing Current WETH ===");
        console.log("WETH address:", CURRENT_WETH);
        
        // 检查合约是否存在
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(CURRENT_WETH)
        }
        console.log("Code size:", codeSize);
        
        if (codeSize > 0) {
            try IWETH(CURRENT_WETH).balanceOf(address(this)) returns (uint256 balance) {
                console.log("Balance check successful:", balance);
                
                // 尝试存款
                try IWETH(CURRENT_WETH).deposit{value: 0.001 ether}() {
                    console.log("Deposit successful");
                    
                    uint256 newBalance = IWETH(CURRENT_WETH).balanceOf(address(this));
                    console.log("New balance:", newBalance);
                } catch {
                    console.log("Deposit failed");
                }
            } catch {
                console.log("Balance check failed");
            }
        } else {
            console.log("No contract code at this address");
        }
    }
    
    receive() external payable {}
}