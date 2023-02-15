// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import { StringsUpgradeable } from '@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol';
import { Base64 } from 'base64-sol/base64.sol';
import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


contract ForcedOffline is Initializable, UUPSUpgradeable, ERC721EnumerableUpgradeable, OwnableUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using StringsUpgradeable for uint256;

    string private constant _SVG_START_TAG = '<svg width="320" height="320" viewBox="0 0 320 320" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">';
    string private constant _SVG_END_TAG = '</svg>';

    CountersUpgradeable.Counter private _tokenIds;
    string[] public talents;
    string[] private backgrounds;
    string[] private weapons;
    string[] private hairs;
    string[] private eyes;

    mapping (uint => uint) public tokenBackground;
    mapping (uint => uint) public tokenTalent;
    mapping (uint => uint) public tokenWeapon;
    mapping (uint => uint) public tokenHair;
    mapping (uint => uint) public tokenEye;
    mapping (uint => string) public tokenName;
    mapping (uint => string) public tokenDescription;

    struct TokenURIParams {
        string name;
        string description;
        string weapon;
        string hair;
        string eye;
        string talent;
        string background;
    }

    struct SVGParams {
        string name;
        string weapon;
        string hair;
        string eye;
        string talent;
        string background;
    }

    function initialize() initializer public {
        __Ownable_init_unchained();
        __ERC721_init_unchained("ForceOffline", "FOL");
        __ERC721Enumerable_init_unchained();
        talents = ["Sniper", "Aviator", "Ninja", "Hacker", "Looter", "Smuggler"];
        backgrounds = ["chartreuse", "darkturquoise", "lightskyblue", "lightsalmon", "lavender"];
        weapons = ["Shield", "Dagger", "Bow", "Revolver", "Rifle" ];
        hairs = ["Fishtail", "Drape", "Stringy", "Slick Shaved", "Short"];
        eyes = ["Statistics Pink", "Statistics Yellow", "Cyber Eyes", "Patch", "Statistics Green"];
    }

    function setName(uint tokenId_, string calldata name_) public {
        require(_exists(tokenId_), "Name set of nonexistent token");
        tokenDescription[tokenId_] = name_;
    }

    function setDescription(uint tokenId_, string calldata description_) public {
        require(_exists(tokenId_), "Description set of nonexistent token");
        tokenDescription[tokenId_] = description_;
    }

    function setBackground(uint tokenId_, uint background_) public {
        require(_exists(tokenId_), "background set of nonexistent token");
        require(background_ < backgrounds.length, "invalid background");
        tokenBackground[tokenId_] = background_;
    }

    function setTalent(uint tokenId_, uint talent_) public {
        require(_exists(tokenId_), "talent set of nonexistent token");
        require(talent_ < talents.length, "invalid talent");
        tokenTalent[tokenId_] = talent_;
    }

    function setWeapon(uint tokenId_, uint weapon_) public {
        require(_exists(tokenId_), "Weapon set of nonexistent token");
        require(weapon_ < weapons.length, "invalid talent");
        tokenWeapon[tokenId_] = weapon_;
    }

    function setHair(uint tokenId_, uint hair_) public {
        require(_exists(tokenId_), "Hair set of nonexistent token");
        require(hair_ < hairs.length, "invalid talent");
        tokenHair[tokenId_] = hair_;
    }

    function setEye(uint tokenId_, uint eye_) public {
        require(_exists(tokenId_), "Eye set of nonexistent token");
        require(eye_ < eyes.length, "invalid talent");
        tokenEye[tokenId_] = eye_;
    }

    function mint(address to, string memory name_, string memory description_,
        uint background_, uint talent_, uint weapon_, uint hair_, uint eye_) public {

        uint256 newItemId = _tokenIds.current();
        _safeMint(to, newItemId);
        tokenName[newItemId] = name_;
        tokenDescription[newItemId] = description_;
        setBackground(newItemId, background_);
        setTalent(newItemId, talent_);
        setWeapon(newItemId, weapon_);
        setHair(newItemId, hair_);
        setEye(newItemId, eye_);

        _tokenIds.increment();
    }

    function tokenURI(uint256 tokenId_) public view override returns (string memory) {
        require(_exists(tokenId_), 'URI query for nonexistent token');
        string memory name = tokenName[tokenId_];
        string memory description = tokenDescription[tokenId_];
        string memory weapon = weapons[tokenWeapon[tokenId_]];
        string memory hair = hairs[tokenHair[tokenId_]];
        string memory eye = eyes[tokenEye[tokenId_]];
        string memory talent = talents[tokenTalent[tokenId_]];
        string memory background = backgrounds[tokenBackground[tokenId_]];

        TokenURIParams memory params = TokenURIParams({
            name: name,
            description: description,
            weapon: weapon,
            hair: hair,
            eye: eye,
            talent: talent,
            background: background
        });
        return constructTokenURI(params);
    }

    function constructTokenURI(TokenURIParams memory params)
        public
        pure
        returns (string memory)
    {
        string memory image = generateSVGImage(
            SVGParams({
            name: params.name,
            talent: params.talent,
            background: params.background,
            weapon: params.weapon,
            hair: params.hair,
            eye: params.eye
        }));

        return string(
            abi.encodePacked(
                'data:application/json;base64,',
                Base64.encode(
                    bytes(
                        abi.encodePacked('{"name":"',
                            params.name,
                            '","description":"',
                            params.description,
                            '","image": "', 'data:image/svg+xml;base64,',
                            image,
                        abi.encodePacked(
                            '","attributes":[',
                                '{"trait_type": "talent", "value": "', params.talent, '"},',
                                '{"trait_type": "weapon", "value": "', params.weapon, '"},',
                                '{"trait_type": "hair", "value": "', params.hair, '"},',
                                '{"trait_type": "eye", "value": "', params.eye, '"},',
                                '{"trait_type": "background", "value": "', params.background, '"}',
                            ']}'))
                    )
                )
            )
        );
    }

    function generateSVGImage(SVGParams memory params)
        internal
        pure
        returns (string memory svg)
    {
        return Base64.encode(bytes(generateSVG(params)));
    }

    function generateSVG(SVGParams memory params) internal pure returns (string memory svg) {

        string memory svg_start = string(
            abi.encodePacked(
                _SVG_START_TAG,
                '<style>.base { fill: white; font-family: serif; font-size: 14px; }</style>'));
        return string(
            abi.encodePacked(
                svg_start,
                '<rect width="100%" height="100%" fill="', params.background, '" />',
                '<text x="50%" y="50%" class="base" dominant-baseline="middle" text-anchor="middle"> ', params.name, ' </text>',
                _SVG_END_TAG
            )
        );
    }
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

}
