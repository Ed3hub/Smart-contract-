//SPDX-License-Identifier:MIT

pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CourseManager} from "src/CourseManager.sol";
import {Ed3Token} from "src/Ed3Token.sol";
import {Ed3Nft} from "src/Ed3Nft.sol";
import {MockStableCoin} from "test/unit/mocks/MockStableCoin.sol";

contract DeployEd3LearnEarn is Script {
    function run() external {
        // Load deployeers private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address nftAddress = address(1);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy mock token
        Ed3Token ed3token = new Ed3Token();
        console.log("Ed3Token deployed at:", address(ed3token));

        // Deploy the Ed3LearnEarnNft
        Ed3Nft ed3nft = new Ed3Nft();
        console.log("Ed3LearnEarnNft deployed at:", address(ed3nft));

        // Deploy mock USDC / USDT
        MockStableCoin usdc = new MockStableCoin("USDC", "USDC", deployer, 6);
        MockStableCoin usdt = new MockStableCoin("USDT", "USDT", deployer, 6);

        address usdcAddress = address(usdc);
        address usdtAddress = address(usdt);

        // Deploy CourseManager
        CourseManager manager =
            new CourseManager(deployer, 200, nftAddress, address(ed3token), usdcAddress, usdtAddress);
        console.log("CourseManager deployed at:", address(manager));

        // Create sample course
        // uint256 courseId =
        //     manager.createCourse("ipfs://sample-course", 10 ether, address(ed3token), 0, usdcAddress, usdtAddress);
        // ed3token.setCourseManager(address(manager));

        // Step 4: Grant CourseManager permissions to mint
        ed3nft.grantRole(ed3nft.MINTER_ROLE(), address(manager));
        ed3token.setCourseManager(address(manager));

        vm.stopBroadcast();
    }
}
