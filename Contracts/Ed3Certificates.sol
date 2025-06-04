// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract Ed3Certificates is ERC721URIStorage, AccessControl, Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    uint256 private _nextTokenId = 1;

    struct Ed3hubCert {
        string courseID;
        string metadataURI;
    }

    mapping(uint256 => Ed3hubCert) private _certificates;

    event CertificateMinted(address indexed student, string courseId, uint256 tokenId);
    
    constructor() ERC721("Ed3hub Certificate", "ED3CERT") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function mintCertificate(
        address student,
        string memory courseId,
        string memory metadataURI
    ) external onlyRole(MINTER_ROLE) whenNotPaused {
        require(student != address(0), "Invalid Student Address");
        require(bytes(courseId).length > 0, "Course ID Required");

        uint256 tokenId = _nextTokenId++;
        _mint(student, tokenId);
        
        _certificates[tokenId] = Ed3hubCert(courseId, metadataURI);
        _setTokenURI(tokenId, metadataURI); // Set the token URI for ERC721URIStorage

        emit CertificateMinted(student, courseId, tokenId);
    }
    
    // Additional functions for pausing and unpausing
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        override(ERC721URIStorage, AccessControl) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }
}