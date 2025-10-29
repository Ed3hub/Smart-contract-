<<<<<<< HEAD
# Ed3Hub
=======
# 🎓 Ed3LearnEarn — A Web3 Educational Platform

> **Empowering learners to earn as they learn.**  
> Built on blockchain to make education transparent, verifiable, and rewarding.

---

## 🧩 Overview

**Ed3LearnEarn** is a decentralized learning platform built on Ethereum where instructors can create tokenized courses and students can enroll, complete, and earn **NFT certificates** as proof of achievement.

It leverages **smart contracts**, **NFTs**, and **on-chain escrow logic** to bring transparency and trust to online education.

---

## 🚀 Features

✅ **Course Creation:**  
Instructors can create courses with metadata stored on IPFS.

✅ **Secure Enrollment:**  
Students can enroll using ETH or ERC20 tokens — payments are held safely in **escrow** until completion.

✅ **Completion Verification:**  
Instructors can mark students as having completed courses.

✅ **NFT Certification:**  
Students automatically receive a **reward NFT** (Ed3LearnEarn NFT) as proof of learning completion.

✅ **Fair Payouts:**  
Instructors withdraw their earnings (minus platform fees) securely after enrollments.

✅ **Platform Fees & Treasury:**  
A small percentage (configurable) is collected as platform fees and sent to the treasury.

---

## 🏗️ Architecture

| Contract | Description |
|-----------|--------------|
| `CourseManager.sol` | Core contract managing courses, enrollments, rewards, and payments. |
| `Ed3LearnEarnNft.sol` | ERC721 NFT contract that mints NFTs when a student completes a course. |
| `MockToken.sol` (for testing) | ERC20 token used to simulate token payments in tests. |

---

## 🔒 Smart Contract Design

- **Escrow Pattern:** Ensures instructors only withdraw funds after courses are completed.
- **Ownable + AccessControl:** Restricts minting and administrative functions.
- **ReentrancyGuard:** Protects from reentrancy exploits.
- **Events:** Every key action emits events for easy indexing and UI updates.

---

## 🧱 Core Contracts

### 🧠 CourseManager.sol

Handles:
- Creating & updating courses  
- Enrollments (ETH / ERC20)
- Withdrawing funds  
- Marking course completion  
- Minting NFTs upon completion  

**Key Events**
```solidity
event CourseCreated(uint256 indexed courseId, address indexed instructor, string uri);
event Enrolled(uint256 indexed courseId, address indexed student, string method);
event CourseCompleted(uint256 indexed courseId, address indexed student, bool completed);
event RewardMinted(uint256 indexed courseId, address indexed student);

| Parameter        | Description                  |
| ---------------- | ---------------------------- |
| **Platform Fee** | 0–20% (configurable)         |
| **Treasury**     | Receives platform fees       |
| **Reward NFT**   | Given upon course completion |


completion
🌐 Future Additions

Decentralized reputation system for instructors

Integration with Arweave/IPFS for course storage

DAO-based governance for fee structures

Learner leaderboard and badge system

👨‍💻 Author

Emmanuel Sharon
Web3 Developer & Blockchain Enthusiast
📬 github.com/sharon-dev-create
 • Twitter- @named_sharon

⚖️ License

This project is licensed under the MIT License.
>>>>>>> 6640a46 (Add initial version of Ed3hub and related contracts)
