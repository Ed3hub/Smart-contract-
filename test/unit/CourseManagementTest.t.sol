//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CourseManager} from "src/CourseManager.sol";
import {Ed3Nft} from "src/Ed3Nft.sol";
import {DeployEd3LearnEarn} from "script/DeployEd3LearnEarn.s.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Ed3Token is ERC20, Ownable {
    constructor() ERC20("ED3TOKEN", "ED3T") Ownable(msg.sender) {
        _mint(msg.sender, 1000000 ether);
    }

    function mintTo(address student, uint256 amount) external {
        _mint(student, amount);
    }
}

contract CourseManagementTest is Test {
    CourseManager public coursemanager;
    Ed3Token public ed3token;
    Ed3Nft public rewardNft;
    // nf.authorizeMinter(address(coursemanager));
    address public instructor = makeAddr("instructor");
    address student = makeAddr("student");
    address treasury = makeAddr("treasury");
    address nftAddress = makeAddr("nftAddress");

    function setUp() public {
        rewardNft = new Ed3Nft();
        ed3token = new Ed3Token();
        coursemanager = new CourseManager(treasury, 200, address(rewardNft), address(ed3token));

        // 1️⃣ Instructor creates a course
        vm.startPrank(instructor);
        uint256 courseId = coursemanager.createCourse("ipfs://course1", 1 ether, address(0), 0);
        vm.stopPrank();

        rewardNft.authorizeMinter(address(coursemanager));

        rewardNft.transferOwnership(address(coursemanager));

        //fund student with ether in test
        vm.deal(student, 10 ether);
        // Mint tokens to students
        ed3token.mintTo(student, 10 ether);

        // ✅ Give CourseManager permission to mint NFTs
        rewardNft.grantRole(rewardNft.MINTER_ROLE(), address(coursemanager));
        rewardNft.grantRole(rewardNft.DEFAULT_ADMIN_ROLE(), instructor);
    }

    function testCourseIsCreated() public {
        vm.prank(instructor);
        uint256 createdCourseId = coursemanager.createCourse("ipfs://course1", 1 ether, address(0), 0);
        (
            uint256 storedCourseId,
            address courseInstructor,
            string memory metadataURI,
            uint256 priceETH,
            ,
            ,
            bool isActive,
            bool canceled,
        ) = coursemanager.courses(createdCourseId);
        assertEq(createdCourseId, 2);
        assertEq(courseInstructor, instructor);
        assertEq(priceETH, 1 ether);
        assertTrue(isActive);
        assertFalse(canceled);
    }

    function testEnrollWithEth() public {
        vm.prank(instructor);
        uint256 courseId = coursemanager.createCourse(("ipfs//course1"), 1 ether, address(0), 0);

        vm.prank(student);
        coursemanager.enrollWithETH{value: 1 ether}(courseId);

        bool enrolled = coursemanager.isEnrolled(courseId, student);
        assertTrue(enrolled);
    }

    function testEnrollWithToken() public {
        vm.prank(instructor);
        uint256 courseId = coursemanager.createCourse(("ipfs//courseId"), 1 ether, address(ed3token), 0);

        vm.startPrank(student);
        ed3token.approve(address(coursemanager), 100 ether);
        coursemanager.enrollWithToken(courseId);
        vm.stopPrank();

        bool enrolled = coursemanager.isEnrolled(courseId, student);
        assertTrue(enrolled);
    }

    function testEnrollWithEthRevertsIfNotEnough() public {
        vm.prank(instructor);
        uint256 courseId = coursemanager.createCourse(("ipfs//courseId"), 1 ether, address(0), 0);

        vm.startPrank(student);
        vm.expectRevert("insufficient ETH");
        coursemanager.enrollWithETH{value: 0.5 ether}(courseId);
        vm.stopPrank();
    }

    function testEnrollWithTokenRevertsIfNotSupported() public {
        vm.prank(instructor);
        uint256 courseId = coursemanager.createCourse(("ipfs//courseId"), 1 ether, address(0), 0);

        vm.startPrank(student);
        vm.expectRevert("token not supported");
        // ed3token.approve(address(ed3token), 1 ether );
        coursemanager.enrollWithToken(courseId);
        vm.stopPrank();
    }

    function testAllowInstructorToWithdrawEth() public {
        vm.startPrank(instructor);
        uint256 courseId = coursemanager.createCourse(("ipfs//courseId"), 1 ether, address(0), 0);
        vm.stopPrank();

        vm.deal(student, 2 ether); //give student enough balance

        vm.prank(student);
        coursemanager.enrollWithETH{value: 1 ether}(courseId);
        console.log("Contract balance", address(coursemanager).balance);

        console.log("Escrow amount:", coursemanager.escrowETH(courseId, instructor));

        vm.prank(instructor);
        coursemanager.withdrawETH(courseId);

        assertGt(instructor.balance, 0, "Instructor have received ETH");
    }

    function testIfCourseIsCompleted() public {
        vm.startPrank(instructor);
        uint256 courseId = coursemanager.createCourse(("ipfs//courseId"), 1 ether, address(0), 0);
        vm.stopPrank();

        vm.deal(student, 2 ether); //give student enough balance
        vm.prank(student);
        coursemanager.enrollWithETH{value: 1 ether}(courseId);

        vm.startPrank(instructor);
        // isEnrolled[courseId][student] = true; // Simulate enrollment for testing

        bool isCourseCompleted = coursemanager.courseCompleted(courseId, student);
        assertFalse(isCourseCompleted, "Course should not be marked as completed yet");

        //Mark course as completed
        coursemanager.markCourseCompleted(courseId, student);

        bool isCompleteAfter = coursemanager.courseCompleted(courseId, student);
        assertTrue(isCompleteAfter, "Course should be marked as completed");

        vm.stopPrank();
    }

    function testMarkCourseCompletedRevertsIfNotEnrolled() public {
        vm.startPrank(instructor);
        uint256 courseId = coursemanager.createCourse(("ipfs//courseId"), 1 ether, address(0), 0);
        vm.stopPrank();

        vm.deal(student, 10 ether);
        vm.prank(student);
        vm.expectRevert("Only instructor can mark completion");

        coursemanager.markCourseCompleted(courseId, student);
    }

    function testMarkCourseCompletedRevertsIfAlreadyCompleted() public {
        vm.startPrank(instructor);
        uint256 courseId = coursemanager.createCourse(("ipfs//courseId"), 1 ether, address(0), 0);
        vm.stopPrank();

        vm.deal(student, 2 ether); //give student enough balance
        vm.prank(student);
        coursemanager.enrollWithETH{value: 1 ether}(courseId);

        vm.startPrank(instructor);
        coursemanager.markCourseCompleted(courseId, student);

        vm.expectRevert("Already completed");
        coursemanager.markCourseCompleted(courseId, student);
        vm.stopPrank();
    }

    function testMarkCourseCompletedEmitsEvent() public {
        vm.startPrank(instructor);
        uint256 courseId = coursemanager.createCourse(("ipfs//courseId"), 1 ether, address(0), 0);
        vm.stopPrank();

        vm.deal(student, 2 ether); //give student enough balance
        vm.prank(student);
        coursemanager.enrollWithETH{value: 1 ether}(courseId);

        vm.startPrank(instructor);
        vm.expectEmit(true, true, false, true);
        emit CourseManager.CourseCompleted(courseId, student, true);
        coursemanager.markCourseCompleted(courseId, student);
        vm.stopPrank();
    }

    // function testStudenthasMintNft() public {
    //     vm.startPrank(instructor);
    //     uint256 courseId = coursemanager.createCourse(("ipfs//courseId"), 1 ether, address(0), 0);
    //     vm.stopPrank();

    //     string memory metadataUri = "ipfs//courseId";
    //     vm.deal(student, 2 ether); //give student enough balance
    //     vm.prank(student);
    //     coursemanager.enrollWithETH{value: 1 ether}(courseId);

    //     vm.startPrank(instructor);
    //     vm.expectEmit(true, true, true, true);
    //     emit CourseManager.CourseCompleted(courseId, student, true);
    //     coursemanager.markCourseCompleted(courseId, student);
    //     vm.stopPrank();

    //     //Test: Instructor mints Nft reward
    //     vm.startPrank(instructor);
    //     vm.expectEmit(true, true, true, true);
    //     emit Ed3LearnEarnNft.RewardMinted(0, student, courseId);
    //     uint256 tokenId = rewardNft.mintNftReward(student, metadataUri, courseId);
    //     vm.stopPrank();

    //     //Check NFT ownership
    //     address nftOwner = rewardNft.ownerOf(tokenId);
    //     assertEq(nftOwner, student, "NFT should belong to student");

    //     //confirm that the reward was marked as minted
    //     bool minted = rewardNft.hasMinted(courseId, student);
    //     assertTrue(minted, "NFT reward should be marked as minted");
    // }
    function testMarkCourseCompletedByStudentsFails() public {
        vm.prank(instructor);
        uint256 courseId = coursemanager.createCourse(("ipfs://metadatauri"), 1 ether, address(0), 0);

        //fund the student with ETH
        vm.deal(student, 2 ether);
        vm.startPrank(student);
        coursemanager.enrollWithETH{value: 1 ether}(courseId);
        vm.stopPrank();

        vm.startPrank(student);
        vm.expectRevert("Only instructor can mark completion");
        coursemanager.markCourseCompleted(courseId, student);
        vm.stopPrank();

        // // Optional: Ensure the course wasn't marked completed
        // bool isCompleted = coursemanager.courseCompleted(courseId, student);
        // assertFalse(isCompleted, "Course should not be marked completed by student");
    }
}
