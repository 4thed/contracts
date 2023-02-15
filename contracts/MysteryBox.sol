// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import { Base64 } from 'base64-sol/base64.sol';
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IForcedOffline {
    function safeTransferFrom(address from, address to, uint256 tokenId ) external;

}

interface IRandomGenerator {
    function requestRandomNumber(uint256 tokenId, address user) external;
}


contract MysteryBox is
Initializable,
UUPSUpgradeable,
ContextUpgradeable,
AccessControlEnumerableUpgradeable,
ERC721EnumerableUpgradeable,
ERC721BurnableUpgradeable,
ERC721PausableUpgradeable,
ERC721HolderUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using AddressUpgradeable for address;
    using StringsUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    event SetRandomGenerator(IRandomGenerator _newRandomGenerator);
    event SetNftToken(IForcedOffline _newNft);
    event Mint(address _to, uint tokenid_);
    event MintMulti(address indexed _to, uint _amount);
    event RevealRequested(uint indexed tokenId, address indexed user_);
    event Reveal(uint indexed tokenId_, uint indexed nftId_);

    string private constant _SVG_START_TAG = '<svg width="320" height="320" viewBox="0 0 320 320" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">';
    string private constant _SVG_END_TAG = '</svg>';

    CountersUpgradeable.Counter private _tokenIdTracker;
    EnumerableSetUpgradeable.UintSet private nftIds;

    bytes32 public merkleRoot;

    uint public totalMysteryBoxQuota;
    uint public totalMysteryBoxSold;

    mapping (address => uint) public whitelistBuyingHistory;
    bool public whiteListOnly;
    uint public whiteListBuyableQuota;

    EnumerableSetUpgradeable.AddressSet private publicBuyerList;
    mapping (address => uint) public publicBuyingHistory;
    uint public publicBuyableQuota;

    IForcedOffline public nftToken;

    IRandomGenerator public randomGenerator;

    uint private INVALID_TOKEN_ID;


    modifier onlyEOA() {
        require(msg.sender == tx.origin, "MysteryBox: not eoa");
        _;
    }

    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE` and `PAUSER_ROLE` to the
     * account that deploys the contract.
     */
    constructor() {}

    function initialize(IForcedOffline nftToken_, IRandomGenerator randomGenerator_, uint totalQuota_)
        public initializer {
        __AccessControlEnumerable_init();
        __ERC721_init_unchained("ForcedOffline Mystery Box", "MysteryBOX");
        __ERC721Enumerable_init_unchained();
        __ERC721Burnable_init_unchained();
        __Pausable_init_unchained();
        __ERC721Pausable_init_unchained();
        __ERC721Holder_init_unchained();

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
        _setupRole(ADMIN_ROLE, _msgSender());

        require(hasRole(ADMIN_ROLE, _msgSender()), "MysteryBox: must have admin role to initialize.");

        nftToken = nftToken_;
        randomGenerator = randomGenerator_;
        clearNftIds();
        for (uint i = 0; i < totalQuota_; i++) {
            nftIds.add(i);
        }        
        INVALID_TOKEN_ID = type(uint).max;
        whiteListBuyableQuota = totalQuota_;
        publicBuyableQuota = totalQuota_;
        totalMysteryBoxQuota = totalQuota_;
    }



    function setRandomGenerator(IRandomGenerator randomGenerator_) onlyRole(ADMIN_ROLE) whenPaused public {
        require(randomGenerator_ != IRandomGenerator(address(0)), "The address of random generator is null");
        randomGenerator = randomGenerator_;
        emit SetRandomGenerator(randomGenerator_);
    }

    function transferAdmin(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(DEFAULT_ADMIN_ROLE, account);
        revokeRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }
    
    function setNftToken(IForcedOffline nftToken_) onlyRole(ADMIN_ROLE) whenPaused public {
        require(nftToken_ != IForcedOffline(address(0)), "The address of IERC721 token is null");
        nftToken = nftToken_;
        emit SetNftToken(nftToken_);
    }

    function _randModulus(address user, uint seed, uint mod) internal view returns (uint) {
        uint rand = uint(keccak256(abi.encodePacked(
                block.timestamp,
                block.difficulty,
                mod,
                user,
                seed,
                _msgSender())
            )) % mod;
        return rand;
    }

    function setWhiteListBuyableQuota(uint whiteListBuyableQuota_) onlyRole(ADMIN_ROLE) whenPaused external {
        whiteListBuyableQuota = whiteListBuyableQuota_;
    }

    function setPublicBuyableQuota(uint publicBuyableQuota_) onlyRole(ADMIN_ROLE) whenPaused external {
        publicBuyableQuota = publicBuyableQuota_;
    }

    function setTotalMysteryBoxQuota(uint totalMysteryBoxQuota_) onlyRole(ADMIN_ROLE) whenPaused external {
        totalMysteryBoxQuota = totalMysteryBoxQuota_;
    }

    function toggleWhiteListOnly() onlyRole(ADMIN_ROLE) whenPaused external {
        if (whiteListOnly) {
            whiteListOnly = false;
        } else {
            whiteListOnly = true;
        }
    }

    function cleanPublicBuyHistory(uint amount) onlyRole(ADMIN_ROLE) whenPaused public returns (bool) {
        uint length = publicBuyerList.length();
        if (length < amount) {
            amount = length;
        }
        for (uint i = 0; i < amount; i++) {
            // modify fix 0 position while iterating all keys
            address buyer = publicBuyerList.at(0);
            delete publicBuyingHistory[buyer];
            publicBuyerList.remove(buyer);
        }
        return true;
    }

    function toBytes32(address addr) pure internal returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    function setMerkleRoot(bytes32 merkleRoot_) external {
        merkleRoot = merkleRoot_;
    }

    function mintMulti(bytes32[] calldata merkleProof, uint amount) whenNotPaused onlyEOA external {
        require(amount > 0, "MysteryBox: missing amount");
        totalMysteryBoxSold += amount;
        require(totalMysteryBoxSold <= totalMysteryBoxQuota, "BindBox: exceeded total mystery box buyable quota.");

        if (whiteListOnly) {
            require(MerkleProofUpgradeable.verify(merkleProof, merkleRoot, toBytes32(msg.sender)) == true,
                "only whitelist allowed");
            require(whitelistBuyingHistory[_msgSender()] + amount <= whiteListBuyableQuota,"Out of whitelist quota");
            whitelistBuyingHistory[_msgSender()] += amount;
        } else {
            require(publicBuyingHistory[_msgSender()] + amount <= publicBuyableQuota, "Out of public sell quota");
            publicBuyingHistory[_msgSender()] += amount;
            publicBuyerList.add(_msgSender());
        }

        for (uint i = 0; i < amount; i++) {
            _mint(_msgSender(), _tokenIdTracker.current());
            emit Mint(_msgSender(),_tokenIdTracker.current());
            _tokenIdTracker.increment();
        }
        emit MintMulti(_msgSender(), amount);
    }

    function reveal(uint tokenId) whenNotPaused onlyEOA external {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "MysteryBox: caller is not owner nor approved");
        randomGenerator.requestRandomNumber(tokenId, _msgSender());
        approve(address(randomGenerator), tokenId);
        emit RevealRequested(tokenId, _msgSender());
    }

    function runFulfillRandomness(uint256 tokenId_, address user_, uint256 randomness_) external {
        require(_msgSender() == address(randomGenerator),
            "MysteryBox: only selected generator can call this method"
        );
        fulfillRandomness(tokenId_, user_, randomness_);
    }

    function fulfillRandomness(uint256 tokenId, address user, uint256 randomness) internal {
        require(_isApprovedOrOwner(user, tokenId), "MysteryBox: user is not owner nor approved");
        burn(tokenId);
        uint index = _randModulus(user, randomness, nftIds.length());
        uint nftId = nftIds.at(index);
        nftIds.remove(nftId);
        IERC721Upgradeable(address(nftToken)).safeTransferFrom(address(this), user, nftId);
        emit Reveal(tokenId, nftId);
    }

    function pause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "MysteryBox: must have pauser role to pause.");
        _pause();
    }

    function unpause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "MysteryBox: must have pauser role to unpause");
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal virtual override (ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721PausableUpgradeable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(AccessControlEnumerableUpgradeable, ERC721Upgradeable, ERC721EnumerableUpgradeable)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function pullNFTs(address tokenAddress, address receivedAddress, uint amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(receivedAddress != address(0));
        require(tokenAddress != address(0));
        uint balance = IERC721Upgradeable(tokenAddress).balanceOf(address(this));
        if (balance < amount) {
            amount = balance;
        }
        for (uint i = 0; i < amount; i++) {
            uint tokenId = IERC721EnumerableUpgradeable(tokenAddress).tokenOfOwnerByIndex(address(this), 0);
            IERC721Upgradeable(tokenAddress).safeTransferFrom(address(this), receivedAddress, tokenId);
        }
    }

    function tokenURI(uint256 tokenId_) public view override returns (string memory) {
        require(_exists(tokenId_), 'URI query for nonexistent token.');
        return constructTokenURI();
    }

    function constructTokenURI()
    public
    pure
    returns (string memory)
    {
        string memory image = generateSVGImage();
        return string(
            abi.encodePacked(
                'data:application/json;base64,',
                Base64.encode(
                    bytes(
                        abi.encodePacked('{"image": "', 'data:image/svg+xml;base64,', image, '"}')
                    )
                )
            )
        );
    }

    function generateSVGImage()
    internal
    pure
    returns (string memory svg)
    {
        return Base64.encode(bytes(generateSVG()));
    }

    function generateSVG() internal pure returns (string memory svg) {

        string memory svg_start = string(
            abi.encodePacked(
                _SVG_START_TAG,
                '<style>.base { fill: white; font-family: serif; font-size: 14px; }</style>'));
        return string(
            abi.encodePacked(
                svg_start,
                '<rect width="100%" height="100%" fill="black" />',
                '<text x="50%" y="50%" class="base" dominant-baseline="middle" text-anchor="middle"> Mystery Box </text>',
                _SVG_END_TAG
            )
        );
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(ADMIN_ROLE) {}

    function clearNftIds() internal {
        uint length = nftIds.length();
        for (uint i = 0; i < length; i++) {
            nftIds.remove(nftIds.at(0));
        }
    }

    function resetNftIds(uint[] calldata nftIds_) public onlyRole(ADMIN_ROLE) {
        uint length = nftIds.length();
        for (uint i = 0; i < length; i++) {
            nftIds.remove(nftIds.at(0));
        }
        for (uint i = 0; i < nftIds_.length; i++) {
          nftIds.add(nftIds_[i]);
        }
    }
}
