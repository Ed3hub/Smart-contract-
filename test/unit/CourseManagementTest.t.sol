//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CourseManager} from "src/CourseManager.sol";
import {Ed3Nft} from "src/Ed3Nft.sol";
import {DeployEd3LearnEarn} from "script/DeployEd3LearnEarn.s.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {MockStableCoin} from "test/unit/mocks/MockStableCoin.sol";

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
    address public instructor = makeAddr("instructor");
    address student = makeAddr("student");
    address treasury = makeAddr("treasury");
    address nftAddress = makeAddr("nftAddress");
    address owner = makeAddr("owner");

    //Mock USDC AND USDT
    MockStableCoin mockUSDC = new MockStableCoin("USDC", "USDC", address(this), 6);
    MockStableCoin mockUSDT = new MockStableCoin("USDT", "USDT", address(this), 6);

    function setUp() public {
        rewardNft = new Ed3Nft();
        ed3token = new Ed3Token();
        coursemanager = new CourseManager(
            treasury, 200, address(rewardNft), address(ed3token), address(mockUSDC), address(mockUSDT)
        );

        // 1️⃣ Instructor creates a course
        vm.startPrank(instructor);
        uint256 courseId = coursemanager.createCourse("ipfs://course1", 1 ether, address(mockUSDC), 50 * 1e6);
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

    modifier InstructorSetUSDCCourse() {
        // ✅ Instructor creates a USDC-paid course
        vm.startPrank(instructor);
        uint256 courseId = coursemanager.createCourse(
            "ipfs://bafkreiged42egxlxf5lqhqk24nvffnhrfiaxtxtqlxybj7fdume346lfiu",
            0, // ✅ No ETH coinPrice
            address(mockUSDC), // ✅ USDC-only course
            10 * 1e6 // ✅ USDC uses 6 decimals
        );
        vm.stopPrank();
        _;
    }

    function testCourseIsCreated() public {
        vm.prank(instructor);
        uint256 createdCourseId = coursemanager.createCourse("ipfs://course1", 1 ether, address(mockUSDC), 50 * 1e6);
        (
            uint256 storedCourseId,
            address courseInstructor,
            string memory metadataURI,
            uint256 coincoinPrice,
            ,
            ,
            bool isActive,
            bool canceled,
        ) = coursemanager.courses(createdCourseId);
        assertEq(createdCourseId, 2);
        assertEq(courseInstructor, instructor);
        // assertEq(coincoinPrice, 50 * 1e6);
        assertTrue(isActive);
        // assertEq(stableToken, address(mockUSDC));
        assertFalse(canceled);
    }

    function testEnrollWithStableCoin() public {
        vm.prank(instructor);
        uint256 courseId = coursemanager.createCourse(("ipfs//course1"), 1 ether, address(mockUSDC), 50 * 1e6);

        mockUSDC.mint(student, 100 * 1e6);

        vm.startPrank(student);
        mockUSDC.approve(address(coursemanager), 50 * 1e6);
        coursemanager.enrollWithStableCoin(courseId);
        vm.stopPrank();

        bool enrolled = coursemanager.isEnrolled(courseId, student);
        assertTrue(enrolled);
    }

    function testEnrollWithToken() public {
        vm.prank(instructor);
        uint256 courseId = coursemanager.createCourse(("ipfs//courseId"), 1 ether, address(mockUSDC), 50 * 1e6);

        mockUSDC.mint(student, 100 * 1e6);

        vm.startPrank(student);
        mockUSDC.approve(address(coursemanager), 50 * 1e6);
        coursemanager.enrollWithStableCoin(courseId);
        vm.stopPrank();

        bool enrolled = coursemanager.isEnrolled(courseId, student);
        assertTrue(enrolled);
    }

    function testEnrollWithStableCoinRevertsIfNotEnough() public {
        // uint256 coinPriceUsdc = 10 * 1e6;
        vm.prank(instructor);
        uint256 courseId = coursemanager.createCourse(("ipfs//courseId"), 0, address(mockUSDC), 2e6);

        vm.startPrank(student);
        mockUSDC.mint(student, 1e6);

        // Student pays in USDC
        vm.startPrank(student);
        mockUSDC.approve(address(coursemanager), 2e6);

        vm.expectRevert("insufficient StableCoin");
        coursemanager.enrollWithStableCoin(courseId);
        vm.stopPrank();
    }

    function testEnrollWithUSDC() public {
        // First create a USDC-coinPriced course
        vm.prank(instructor);

        uint256 coinPriceUsdc = 50 * 1e6;
        uint256 courseId = coursemanager.createCourse(("ipfs//course-usdc"), 1 ether, address(mockUSDC), coinPriceUsdc);

        // Student gets USDC
        mockUSDC.mint(student, 100 * 1e6);

        // Student pays in USDC
        vm.startPrank(student);
        mockUSDC.approve(address(coursemanager), coinPriceUsdc);

        // Student enrolls
        coursemanager.enrollWithStableCoin(courseId);
        vm.stopPrank();

        // Validate enrollment
        bool enrolled = coursemanager.isEnrolled(courseId, student);
        assertTrue(enrolled);
    }

    function testAllowInstructorToWithdraw() public {
        vm.startPrank(instructor);
        uint256 amount = 50 * 1e6;
        uint256 courseId = coursemanager.createCourse(("ipfs//course-usdc"), 1 ether, address(mockUSDC), amount);
        vm.stopPrank();

        // Student gets USDC
        mockUSDC.mint(student, 100 * 1e6);

        // Student pays in USDC
        vm.startPrank(student);
        mockUSDC.approve(address(coursemanager), amount);
        coursemanager.enrollWithStableCoin(courseId);
        vm.stopPrank();

        uint256 balanceBefore = mockUSDC.balanceOf(instructor);

        vm.prank(instructor);
        coursemanager.withdraw(courseId, address(mockUSDC));

        uint256 balanceAfter = mockUSDC.balanceOf(instructor);

        assertGt(balanceAfter, balanceBefore, "Instructor have received StableCoin");
    }

    function testIfCourseIsCompleted() public {
        // ✅ Instructor creates a USDC-paid course
        vm.startPrank(instructor);
        uint256 courseId = coursemanager.createCourse(
            "ipfs://bafkreiged42egxlxf5lqhqk24nvffnhrfiaxtxtqlxybj7fdume346lfiu",
            0, // ✅ No ETH coinPrice
            address(mockUSDC), // ✅ USDC-only course
            10 * 1e6 // ✅ USDC uses 6 decimals
        );
        vm.stopPrank();

        // ✅ Give student USDC and approve spending
        mockUSDC.mint(student, 20 * 1e6);

        vm.startPrank(student);
        mockUSDC.approve(address(coursemanager), 20 * 1e6);

        // ✅ Enroll using stablecoin
        coursemanager.enrollWithStableCoin(courseId);
        vm.stopPrank();

        // ✅ Before completion
        bool isBefore = coursemanager.courseCompleted(courseId, student);
        assertFalse(isBefore);

        // ✅ Mark course completed
        vm.prank(instructor);
        coursemanager.markCourseCompleted(courseId, student);

        // ✅ After completion
        bool isAfter = coursemanager.courseCompleted(courseId, student);
        assertTrue(isAfter);
    }

    function testMarkCourseCompletedRevertsIfNotEnrolled() public InstructorSetUSDCCourse {
        uint256 courseId = coursemanager.createCourse(
            "ipfs://bafkreiged42egxlxf5lqhqk24nvffnhrfiaxtxtqlxybj7fdume346lfiu",
            0, // ✅ No ETH coinPrice
            address(mockUSDC), // ✅ USDC-only course
            10 * 1e6 // ✅ USDC uses 6 decimals
        );

        vm.deal(student, 10 ether);
        vm.prank(student);
        vm.expectRevert("Only instructor can mark completion");

        coursemanager.markCourseCompleted(courseId, student);
    }

    function testMarkCourseCompletedRevertsIfAlreadyCompleted() public {
        uint256 courseId = coursemanager.createCourse(
            "ipfs://bafkreiged42egxlxf5lqhqk24nvffnhrfiaxtxtqlxybj7fdume346lfiu",
            1 ether, //  coinPrice
            address(mockUSDC), // ✅ USDC-only course
            10 * 1e6 // ✅ USDC uses 6 decimals
        );

        // ✅ Give student USDC and approve spending
        mockUSDC.mint(student, 20 * 1e6);

        vm.startPrank(student);
        mockUSDC.approve(address(coursemanager), 20 * 1e6);

        // ✅ Enroll using stablecoin
        coursemanager.enrollWithStableCoin(courseId);
        vm.stopPrank();

        vm.startPrank(instructor);
        vm.expectRevert(bytes("Only instructor can mark completion"));
        coursemanager.markCourseCompleted(courseId, student);
        vm.stopPrank();
    }

    function testMarkCourseCompletedEmitsEvent() public {
        vm.startPrank(instructor);
        uint256 courseId = coursemanager.createCourse(
            "ipfs://bafkreiged42egxlxf5lqhqk24nvffnhrfiaxtxtqlxybj7fdume346lfiu",
            1 ether, // ✅ No ETH coinPrice
            address(mockUSDC), // ✅ USDC-only course
            10 * 1e6 // ✅ USDC uses 6 decimals
        );
        vm.stopPrank();

        mockUSDC.mint(student, 20 * 1e6);

        vm.startPrank(student);
        mockUSDC.approve(address(coursemanager), 20 * 1e6);

        // ✅ Enroll using stablecoin
        coursemanager.enrollWithStableCoin(courseId);
        vm.stopPrank();

        vm.startPrank(instructor);
        vm.expectEmit(true, true, false, true);
        emit CourseManager.CourseCompleted(courseId, student, true);
        coursemanager.markCourseCompleted(courseId, student);
        vm.stopPrank();
    }

    function testMarkCourseCompletedByStudentsFails() public {
        uint256 courseId = coursemanager.createCourse(
            "ipfs://bafkreiged42egxlxf5lqhqk24nvffnhrfiaxtxtqlxybj7fdume346lfiu",
            1 ether, // ✅ No ETH coinPrice
            address(mockUSDC), // ✅ USDC-only course
            10 * 1e6 // ✅ USDC uses 6 decimals
        );

        //fund the student with ETH
        mockUSDC.mint(student, 20 * 1e6);
        vm.startPrank(student);
        mockUSDC.approve(address(coursemanager), 20 * 1e6);

        // ✅ Enroll using stablecoin
        coursemanager.enrollWithStableCoin(courseId);
        vm.stopPrank();

        vm.startPrank(student);
        vm.expectRevert("Only instructor can mark completion");
        coursemanager.markCourseCompleted(courseId, student);
        vm.stopPrank();
    }
}
