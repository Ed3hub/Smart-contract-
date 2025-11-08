// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FundCourseManager is Script {
    function run() external {
        // -------------------------------
        // CONFIG
        // -------------------------------
        address courseManager = vm.envAddress("COURSE_MANAGER");
        address token = vm.envAddress("TOKEN_ADDRESS");  // USDC or USDT contract
        uint256 amount = vm.envUint("AMOUNT");           // Example: 100000000 (100 USDC with 6 decimals)

        vm.startBroadcast();

        // --------------------------------
        // FUND WITH ETH (optional)
        // --------------------------------
        payable(courseManager).transfer(0.5 ether);

        // --------------------------------
        // FUND WITH ERC20 TOKEN
        // --------------------------------
        IERC20(token).transfer(courseManager, amount);

        vm.stopBroadcast();

        console.log("Funded CourseManager:", courseManager);
        console.log("Token:", token);
        console.log("Amount:", amount);
    }
}
