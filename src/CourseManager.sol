// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {Ed3Nft} from "src/Ed3Nft.sol";

/// @title CourseManager - A web3 Educational Platform Contract
/// @author Emmanuel Sharon
/// @notice This contract manages courses, enrollments, and certifications on a web3 educational platform.
/// @dev Supports ETH & ERC20 token payments with satety gaurds

interface IEd3Token {
    function mintReward(address student, uint256 amount) external;
}

interface IEd3LearnEarnNFT {
    function mintNftReward(address student, string calldata metadataUri, uint256 courseId) external;
}

contract CourseManager is ReentrancyGuard, Ownable(msg.sender) {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    /**
     * =====STRUCTS AND STORAGE
     */
    struct Course {
        uint256 courseId;
        address instructor;
        string metadataURI; // IPFS/Arweave link to course content/metadata
        uint256 priceETH; //price of ETH in wei
        address priceToken; // ERC20 token address for payment, address(0) for ETH
        uint256 priceTokenAmount; // Amount in smallest unit (wei for ETH, token decimals for ERC20)
        bool isActive;
        bool canceled;
        address[] enrolledStudents;
        address nftAddress;
    }

    struct Enrollment {
        bool enrolled;
        bool completed;
    }

    /**
     * MAPPINGS
     */
    mapping(uint256 => Course) public courses;
    // To track enrollments
    mapping(uint256 => EnumerableSet.AddressSet) private enrolled;

    // Escrow balances for instructors (pull payments)
    mapping(uint256 => mapping(address => uint256)) public escrowETH; // courseId => instructor => wei
    mapping(uint256 => mapping(address => uint256)) public escrowToken; // courseId => instructor => tokenAmount

    //Track how much each studentspaid for refunds
    mapping(uint256 => mapping(address => uint256)) public ethPaid;
    mapping(uint256 => mapping(address => uint256)) public tokenPaid;

    //Track completion and rewards
    mapping(uint256 => mapping(address => bool)) public courseCompleted;
    mapping(uint256 => mapping(address => bool)) public rewardClaimed;

    /**
     * STATE VARIABLES
     */
    uint256 public nextCourseId;
    uint256 public rewardAmount;
    address public admin;
    IEd3Token public ed3token;
    Ed3Nft public ed3Nft;

    /**
     * MODIFIERS
     */
    modifier courseExists(uint256 courseId) {
        require(courseId > 0 && courseId <= nextCourseId, "course not found");
        _;
    }

    // Platform fee (basis points, e.g., 200 = 2%)
    uint16 public platformFees;
    address public treasury;

    /**
     * CONSTRUCTOR
     */
    constructor(address _treasury, uint16 _platformFees, address _rewardNft, address _ed3Token) {
        require(_treasury != address(0), "invalid treasury acct");
        require(_platformFees <= 2000, "fee too high"); //<20% gaurd
        ed3Nft = Ed3Nft(_rewardNft);
        treasury = _treasury;
        platformFees = _platformFees;
        ed3token = IEd3Token(_ed3Token);
    }
    /**
     * EVENTS
     */

    event CourseCreated(uint256 indexed courseId, address indexed instructor, string uri);
    event CourseUpdated(uint256 indexed courseId, bool isActive);
    event CourseCanceled(uint256 indexed courseId, bool isCanceled);
    event Enrolled(uint256 indexed courseId, address indexed student, string method);
    event InstructorWithdrawed(
        uint256 indexed courseId, address indexed instructor, uint256 indexed ethAmount, string method
    );
    event PlatformFeeChanged(uint16 indexed feePtng, address newTreasury);
    event CourseCompleted(uint256 indexed courseId, address indexed student, bool completed);
    event RewardClaimed(uint256 indexed courseId, address indexed student, uint256 amount);
    event RewardMinted(uint256 indexed courseId, address indexed student);

    /**
     * =====COURSE MANAGEMENT
     */
    ///When you call this function, the instructor creates a new course and stores it in courses[courseId]
    function createCourse(string calldata uri, uint256 priceETH, address priceToken, uint256 priceTokenAmount)
        external
        returns (uint256)
    {
        uint256 courseId = ++nextCourseId;
        // courses[nextCourseId] = Course(nextCourseId, name, reward);

        courses[courseId] = Course({
            courseId: courseId,
            instructor: msg.sender,
            metadataURI: uri,
            priceETH: priceETH,
            priceToken: priceToken,
            priceTokenAmount: priceTokenAmount,
            isActive: true,
            canceled: false,
            enrolledStudents: new address[](0),
            nftAddress: address(0)
        });

        emit CourseCreated(courseId, msg.sender, uri); //broadcast event that a new course was created
        return courseId;
    }

    // Instuctor can toggle course active status
    function setCourseToActive(bool isActive, uint256 courseId) external {
        Course storage cm = courses[courseId];
        require(msg.sender == cm.instructor, "Must be instructor");
        require(!cm.canceled, "course is canceled");
        cm.isActive = isActive;

        emit CourseUpdated(courseId, isActive);
    }

    //Instructor can cancel the course
    function cancelCourse(bool isCanceled, uint256 courseId) external {
        Course storage cmc = courses[courseId];
        require(msg.sender == cmc.instructor, "MUst be instructor");
        require(!cmc.canceled, "course is canceled");
        cmc.isActive = false;
        cmc.canceled = true;

        emit CourseCanceled(courseId, isCanceled);
    }

    // ENROLLMENT (ESCROW PATTERN)

    //Allow leaners to pay for a course with ETH
    function enrollWithETH(uint256 courseId) external payable courseExists(courseId) {
        Course storage cm = courses[courseId];
        require(cm.isActive && !cm.canceled, "not available");
        require(cm.priceETH > 0, "not payable by ETH");
        require(msg.value >= cm.priceETH, "insufficient ETH");
        if (msg.value > cm.priceETH) {
            (bool refunded,) = payable(msg.sender).call{value: msg.value - cm.priceETH}("");
            require(refunded, "refund failed");
        }

        //mark enrollment before external state modifications
        bool added = enrolled[courseId].add(msg.sender);
        require(added, "Already enrolled");

        // transfer ETH to instructor
        // payable(cm.instructor).transfer(msg.value);

        // compute the pltform fee
        uint256 fee = (msg.value * platformFees) / 10000;
        uint256 instructorShare = msg.value - fee;

        // store in escrow (pull pattern)
        escrowETH[courseId][cm.instructor] += instructorShare;
        escrowETH[courseId][treasury] += fee;

        ethPaid[courseId][msg.sender] += msg.value;

        emit Enrolled(courseId, msg.sender, "ETH");
    }

    // Enroll payable with ERC20 token (contract hold in escrow)
    function enrollWithToken(uint256 courseId) external courseExists(courseId) {
        Course storage cm = courses[courseId];
        require(cm.isActive && !cm.canceled, "not available");
        require(cm.priceToken != address(0), "token not supported");
        uint256 price = cm.priceTokenAmount; //set price of token

        //transfer tokens into contract first
        IERC20(cm.priceToken).safeTransferFrom(msg.sender, address(this), price);

        //mark enrolled
        bool added = enrolled[courseId].add(msg.sender);
        require(added, "Already enrolled");
        tokenPaid[courseId][msg.sender] += price;

        //Give Instructor share
        uint256 fee = (price * platformFees) / 10000;
        uint256 instructorShare = price - fee;

        escrowToken[courseId][cm.instructor] += instructorShare;
        escrowToken[courseId][treasury] += fee;

        emit Enrolled(courseId, msg.sender, "TOKEN");
    }

    /**
     * WITHDRAWALS
     */

    //Instructor(treasury) withdraws ETH for a course
    function withdrawETH(uint256 courseId) external nonReentrant courseExists(courseId) {
        uint256 amount = escrowETH[courseId][msg.sender];
        require(amount > 0, "Not enough amount");
        escrowETH[courseId][msg.sender] = 0;
        //make the call to withdraw Eth
        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "ETH withdrawal failed");

        emit InstructorWithdrawed(courseId, msg.sender, amount, "");
    }

    //Withdraw Token
    function withdrawToken(uint256 courseId, address tokenAddr) external nonReentrant courseExists(courseId) {
        uint256 amount = escrowToken[courseId][msg.sender];
        require(amount > 0, "not enough Token");
        escrowToken[courseId][msg.sender] = 0;

        IERC20(tokenAddr).safeTransfer(msg.sender, amount);
        emit InstructorWithdrawed(courseId, msg.sender, amount, "TOKEN");
    }

    function markCourseCompleted(uint256 courseId, address student) external courseExists(courseId) {
        Course storage cm = courses[courseId];
        // Ensure only instructor can mark completion
        require(msg.sender == cm.instructor, "Only instructor can mark completion");
        require(enrolled[courseId].contains(student), "Not enrolled");
        require(!courseCompleted[courseId][student], "Already completed");

        // Mark as completed
        courseCompleted[courseId][student] = true;

        // Emit event
        emit CourseCompleted(courseId, student, true);

        // Reward the student with tokens/NFt
        ed3Nft.mintNftReward(student, "", courseId);
    }

    function claimTokenReward(uint256 courseId) external courseExists(courseId) {
    require(courseCompleted[courseId][msg.sender], "Course not completed");
    require(!rewardClaimed[courseId][msg.sender], "Already claimed");

    rewardClaimed[courseId][msg.sender] = true;

    ed3token.mintReward(msg.sender, rewardAmount);

    emit RewardClaimed(courseId, msg.sender, rewardAmount);
}


    // Mint Reward
    function mintNftReward(address student, string calldata metadataUri, uint256 courseId)
        external
        onlyOwner
        courseExists(courseId)
        returns (uint256)
    {
        require(courseCompleted[courseId][student], "Course not completed Yet");
        require(!ed3Nft.hasMinted(courseId, student), "Reward has already been minted");
        // string memory metadataUri = "ipfs://Example";

        //mint to student
        uint256 tokenId = ed3Nft.mintNftReward(student, metadataUri, courseId);

        //Emit
        emit RewardMinted(courseId, student);
        return (tokenId);
    }

    function setRewardConfig(address _ed3Token, uint256 _rewardAmount) 
    external onlyOwner {
        require(_ed3Token != address(0), "Invalid token address");
        require(_rewardAmount > 0, "Reward amount must be > 0");
        ed3token = IEd3Token(_ed3Token);
        rewardAmount = _rewardAmount;
    }

    /**
     * VIEW/ GETTER FUNCTIONS
     */
    function isEnrolled(uint256 courseId, address student) external view returns (bool) {
        return enrolled[courseId].contains(student);
    }

    function enrolledCount(uint256 courseId) external view returns (uint256) {
        return enrolled[courseId].length();
    }

    function getEnrolled(uint256 courseId) external view returns (address[] memory) {
        return enrolled[courseId].values();
    }

    // ADMIN TO SET FEES
    function setCourseFees(uint16 feePtng, address _treasury) external onlyOwner {
        require(feePtng <= 2000, "fee too high");
        require(_treasury != address(0), "Invalid treasury");
        platformFees = feePtng;
        treasury = _treasury;
        emit PlatformFeeChanged(feePtng, _treasury);
    }

    /* ========== RECEIVE / FALLBACK ========== */
    receive() external payable {}
    fallback() external payable {}
}
