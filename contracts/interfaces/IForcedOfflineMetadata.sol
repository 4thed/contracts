// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IForcedOfflineMetadata {
    function tokenURI(uint256 tokenId_) external view returns (string memory);
    function setDescription(uint256 tokenId_, string calldata description_) external;
    function setBaseURI(string calldata baseURI_) external;
}
