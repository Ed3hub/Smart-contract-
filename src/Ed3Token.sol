//SPDX-License-Identifier:MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title LearnToken - Utility token for Ed3LearnEarn ecosystem
/// @notice Used for rewarding learners and interacting with courses/NFTs
/// @dev Inherits ERC20 and Ownable from OpenZeppelin for safety

contract Ed3Token is ERC20, Ownable {
    // Address of the courseManager contract allowed to mint tokens
    address public courseManager;

    // Reward per completed course
    uint256 public rewardAmount = 100 * 10 ** 18; // 100 LTN

    // Event emitted when rewards are minted for a learner
    event RewardMinted(address student, uint256 indexed rewardAmount);
    event CourseManagerSet(address indexed manager);

    constructor() ERC20("Ed3Token", "ED3") Ownable(msg.sender) {
        _mint(msg.sender, 1_000_000 * 10 * 18 ether);
    }

    function setCourseManager(address _manager) external onlyOwner {
        courseManager = _manager;
        require(_manager != address(0), "Invalid manager address");
        emit CourseManagerSet(_manager);
    }

    function mintReward(address student, uint256 amount) external {
        require(student != address(0), "Invalid address");
        require(msg.sender == courseManager, "Not authorized");
        require(amount > 0, "Amount must be greater than zero");
        _mint(student, rewardAmount);

        emit RewardMinted(student, rewardAmount);
    }

    //@notice Ser reward amount per course completion
    function setRewardAmount(uint256 _amount) external onlyOwner {
        rewardAmount = _amount;
    }
}
