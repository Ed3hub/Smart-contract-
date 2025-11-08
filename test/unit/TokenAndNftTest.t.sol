//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CourseManager} from "src/CourseManager.sol";
import {Ed3Nft} from "src/Ed3Nft.sol";
import {Ed3Token} from "src/Ed3Token.sol";

contract TokenAndNftTest is Test {
    Ed3Token public ed3token;
    Ed3Nft public ed3Nft;

    address owner = makeAddr("owner");
    address admin = makeAddr("admin");
    address courseManager = makeAddr("courseManager");
    address student = makeAddr("student");
    address minter = makeAddr("minter");

    function setUp() public {
        vm.startPrank(owner);
        ed3token = new Ed3Token();
        ed3Nft = new Ed3Nft();
        ed3Nft.grantRole(ed3Nft.MINTER_ROLE(), minter);
        vm.stopPrank();
    }

    function testInitialTokenSetup() public {
        assertEq(ed3token.name(), "Ed3Token");
        assertEq(ed3token.symbol(), "ED3");
        assertGt(ed3token.totalSupply(), 0);
        assertEq(ed3token.owner(), owner);
    }

    function testOnlyOwnerCanSetCourseManager() public {
        //should succeed for owner
        vm.prank(owner);
        ed3token.setCourseManager(courseManager);
        assertEq(ed3token.courseManager(), courseManager);

        //Should revert if not owner
        vm.prank(student);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), student));
        ed3token.setCourseManager(student);
    }

    function testOwnerCanUpdateRewardAmount() public {
        vm.prank(owner);
        ed3token.setRewardAmount(500 ether);
        assertEq(ed3token.rewardAmount(), 500 ether);
    }

    function testOnlyCourseManagerCanMintRewards() public {
        vm.prank(owner);
        ed3token.setCourseManager(courseManager);

        //should revert if not courseManager
        vm.prank(student);
        vm.expectRevert("Not authorized");
        ed3token.mintReward(student, 100 ether);

        //should succeed for courseManager
        vm.prank(courseManager);
        ed3token.mintReward(student, 100 ether);
        assertEq(ed3token.balanceOf(student), ed3token.rewardAmount());
    }

    function testMintNftRewardEmitsEvent() public {
        string memory metadataUri = "ipfs://bafkreiged42egxlxf5lqhqk24nvffnhrfiaxtxtqlxybj7fdume346lfiu";
        uint256 courseId = 1;

        vm.startPrank(minter);
        vm.expectEmit(true, true, true, false);
        emit Ed3Nft.RewardMinted(0, student, courseId);

        uint256 tokenId = ed3Nft.mintNftReward(student, metadataUri, courseId);
        vm.stopPrank();

        assertEq(ed3Nft.ownerOf(tokenId), student);
    }

    function testRevertsIfNotMinter() public {
        string memory metadataUri = "ipfs://bafkreiged42egxlxf5lqhqk24nvffnhrfiaxtxtqlxybj7fdume346lfiu";
        uint256 courseId = 1;

        vm.startPrank(student);
        vm.expectRevert();
        ed3Nft.mintNftReward(student, metadataUri, courseId);
        vm.stopPrank();
    }

    function testIfNftHasbeenMinted() public {
        vm.startPrank(owner);
        ed3Nft.grantRole(ed3Nft.MINTER_ROLE(), minter);
        vm.stopPrank();

        string memory metadataUri = "ipfs://bafkreiged42egxlxf5lqhqk24nvffnhrfiaxtxtqlxybj7fdume346lfiu";
        uint256 courseId = 0;

        vm.startPrank(minter);
        uint256 tokenId = ed3Nft.mintNftReward(student, metadataUri, courseId);
        vm.stopPrank();

        assertEq(ed3Nft.ownerOf(tokenId), student);
        bool hasMinted = ed3Nft.hasMinted(courseId, student);
        assertEq(hasMinted, true);
    }

    function testMintNftRewardRevertsIfToIsZeroAddress() public {
        vm.startPrank(owner);
        ed3Nft.grantRole(ed3Nft.MINTER_ROLE(), minter);
        vm.stopPrank();

        string memory metadataUri = "ipfs://metadata";
        uint256 courseId = 1;

        vm.prank(student);
        vm.expectRevert();
        ed3Nft.mintNftReward(address(0), metadataUri, courseId);
    }

    function testTokenURIReturnsCorrectURI() public {
        vm.startPrank(owner);
        ed3Nft.grantRole(ed3Nft.MINTER_ROLE(), minter);
        vm.stopPrank();

        string memory baseURI = "ipfs://baseURI/";
        vm.prank(owner);
        ed3Nft.setBaseURI(baseURI);

        string memory metadataUri = "metadata.json";
        uint256 courseId = 1;

        vm.startPrank(minter);
        uint256 tokenId = ed3Nft.mintNftReward(student, metadataUri, courseId);
        vm.stopPrank();

        string memory expectedURI = string(abi.encodePacked(baseURI, "0"));
        string memory actualURI = ed3Nft.tokenURI(tokenId);
        assertEq(actualURI, expectedURI);
    }
}
