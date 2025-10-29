// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {CourseManager} from "src/CourseManager.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract Ed3Nft is ERC721URIStorage, AccessControl, Ownable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 private _nextTokenId;

    string private _baseTokenURI;
    // rewardNft.authorizeMinter(address(coursemanager));

    mapping(uint256 => mapping(address => bool)) public minted;

    event RewardMinted(uint256 indexed tokenId, address indexed to, uint256 indexed courseId);

    // constructor where admin is the deployer
    constructor() ERC721("Ed3LearnRewardNft", "ED3NFT") Ownable(msg.sender) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);

        _nextTokenId = 0;
    }

    // @notice Admin can authorise another courseManger contract to mint
    function authorizeMinter(address courseManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MINTER_ROLE, courseManager);
    }

    //Mint the reward NFT to the learner
    function mintNftReward(address to, string calldata metadataUri, uint256 courseId)
        external
        onlyRole(MINTER_ROLE)
        returns (uint256)
    {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        //store the metadataUri for the tokenId
        if (bytes(metadataUri).length > 0) {
            //we'll store it in the tokenURI mapping
            _setTokenURI(tokenId, metadataUri);
        }
        emit RewardMinted(tokenId, to, courseId);
        return tokenId;
    }

    // Convert uint256 to string
    function _toString(uint256 value) internal pure returns (string memory) {
        return Strings.toString(value);
    }

    // Set base URI for all tokens
    function setBaseURI(string calldata baseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _baseTokenURI = baseURI;
    }

    // Override tokenURI to return the full URI
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "ERC721: non existent token");
        if (bytes(_baseTokenURI).length > 0) {
            return string(abi.encodePacked(_baseTokenURI, _toString(tokenId)));
        }
        return super.tokenURI(tokenId);
    }

    function hasMinted(uint256 courseId, address student) external view returns (bool) {
        return minted[courseId][student];
    }

    // Override supportsInterface to include AccessControl
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
