// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/*
███████╗ ██████╗ ██████╗  ██████╗███████╗██████╗      ██████╗ ███████╗███████╗██╗     ██╗███╗   ██╗███████╗
██╔════╝██╔═══██╗██╔══██╗██╔════╝██╔════╝██╔══██╗    ██╔═══██╗██╔════╝██╔════╝██║     ██║████╗  ██║██╔════╝
█████╗  ██║   ██║██████╔╝██║     █████╗  ██║  ██║    ██║   ██║█████╗  █████╗  ██║     ██║██╔██╗ ██║█████╗
██╔══╝  ██║   ██║██╔══██╗██║     ██╔══╝  ██║  ██║    ██║   ██║██╔══╝  ██╔══╝  ██║     ██║██║╚██╗██║██╔══╝
██║     ╚██████╔╝██║  ██║╚██████╗███████╗██████╔╝    ╚██████╔╝██║     ██║     ███████╗██║██║ ╚████║███████╗
╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚══════╝╚═════╝      ╚═════╝ ╚═╝     ╚═╝     ╚══════╝╚═╝╚═╝  ╚═══╝╚══════╝
*/

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import { Strings } from '@openzeppelin/contracts/utils/Strings.sol';
import { Base64 } from 'base64-sol/base64.sol';
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "./interfaces/IForcedOfflineMetadata.sol";
import "./interfaces/IForcedOffline.sol";

contract ForcedOffline is
Initializable,
AccessControlEnumerable,
ERC721Enumerable,
IForcedOffline
{
    using Counters for Counters.Counter;
    using Strings for uint256;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/
    bytes32 public constant REVEALER_ROLE = keccak256("REVEALER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    Counters.Counter private _tokenIds;

    mapping (uint => bool) public revealed;

    string public defaultBaseURI;

    uint public totalQuota;
    uint public totalSold;

    address public metadataAddress;

    /// @dev This event emits when the metadata of a token is changed.
    /// So that the third-party platforms such as NFT market could
    /// timely update the images and related attributes of the NFT.
    event MetadataUpdate(uint256 _tokenId);

    /// @dev This event emits when the metadata of a range of tokens is changed.
    /// So that the third-party platforms such as NFT market could
    /// timely update the images and related attributes of the NFTs.
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    /*//////////////////////////////////////////////////////////////
                           CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() ERC721("ForceOffline", "FOL") {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(REVEALER_ROLE, _msgSender());
        _setupRole(ADMIN_ROLE, _msgSender());

        defaultBaseURI = "";
        totalQuota = 500;
    }


    /*//////////////////////////////////////////////////////////////
                               MINTING LOGIC
    //////////////////////////////////////////////////////////////*/
    function mint(address to) onlyRole(ADMIN_ROLE) public {
        uint256 newItemId = _tokenIds.current();
        require(newItemId < totalQuota, "exceeding quota");
        totalSold += 1;
        _safeMint(to, newItemId);
        _tokenIds.increment();
    }

    function mintMulti(address to, uint amount) onlyRole(ADMIN_ROLE) external {
        require(amount > 0, "ForcedOffline: missing amount");
        require(totalSold + amount <= totalQuota, "exceeding quota");
        for (uint i = 0; i < amount; i++) {
            mint(to);
        }
    }

    /*//////////////////////////////////////////////////////////////
                           REVEALING LOGIC
    //////////////////////////////////////////////////////////////*/
    function reveal(uint tokenId_) onlyRole(REVEALER_ROLE) public {
        require(_exists(tokenId_), 'ForcedOffline: nonexistent token');
        revealed[tokenId_] = true;
    }

    function hasRevealed(uint tokenId_) public view returns (bool){
        return revealed[tokenId_];
    }

    /*//////////////////////////////////////////////////////////////
                             URI LOGIC
    //////////////////////////////////////////////////////////////*/
    function _baseURI() internal view virtual override returns (string memory) {
        return defaultBaseURI;
    }

    function tokenURI(uint256 tokenId_) public view override returns (string memory) {
        require(_exists(tokenId_), 'URI query for nonexistent token');
        if (! hasRevealed(tokenId_)) {
            return "";
        }
        return IForcedOfflineMetadata(metadataAddress).tokenURI(tokenId_);
    }

    function setDefaultBaseURI(string memory defaultBaseURI_) onlyRole(ADMIN_ROLE) external {
        defaultBaseURI = defaultBaseURI_;
        IForcedOfflineMetadata(metadataAddress).setBaseURI(defaultBaseURI_);
    }

    /*//////////////////////////////////////////////////////////////
                              METADATA LOGIC
    //////////////////////////////////////////////////////////////*/
    function setDescription(uint tokenId_, string calldata description_) onlyRole(ADMIN_ROLE) external {
        require(_exists(tokenId_), "Description set of nonexistent token");
        IForcedOfflineMetadata(metadataAddress).setDescription(tokenId_, description_);
    }

    function notifyBatchMetadataUpdated(uint256 fromTokenId_, uint256 toTokenId_) onlyRole(ADMIN_ROLE) external {
        emit BatchMetadataUpdate(fromTokenId_, toTokenId_);
    }

    function notifyMetadataUpdated(uint256 tokenId_) onlyRole(ADMIN_ROLE) external {
        emit MetadataUpdate(tokenId_);
    }

    /*//////////////////////////////////////////////////////////////
                         CONFIGURE LOGIC
    //////////////////////////////////////////////////////////////*/
    function setMetadataConfig(address metadataAddress_) onlyRole(ADMIN_ROLE) external {
        require(metadataAddress_ != address(0), "The address of metadata config is null");
        metadataAddress = metadataAddress_;
    }

    function setTotalQuota(uint totalQuota_) onlyRole(ADMIN_ROLE) external {
        totalQuota = totalQuota_;
    }

    function setTotalSold(uint totalSold_) onlyRole(ADMIN_ROLE) external {
        totalSold = totalSold_;
    }

    function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(AccessControlEnumerable, ERC721Enumerable)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN LOGIC
    //////////////////////////////////////////////////////////////*/
    function transferAdmin(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(DEFAULT_ADMIN_ROLE, account);
        revokeRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

}
