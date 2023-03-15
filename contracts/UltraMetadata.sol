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
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import { Strings } from '@openzeppelin/contracts/utils/Strings.sol';
import { Base64 } from 'base64-sol/base64.sol';
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IForcedOfflineMetadata.sol";

contract UltraMetadata is Ownable, IForcedOfflineMetadata {
    using Strings for uint256;

    /*//////////////////////////////////////////////////////////////
                           BITWISE CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint constant private TOTAL_DNA_SIZE = 32;
    uint constant private ULTRA_BACKGROUND_DNA_POSITION = TOTAL_DNA_SIZE - 5;
    uint constant private ULTRA_WEAPON_DNA_POSITION = ULTRA_BACKGROUND_DNA_POSITION - 2;
    uint constant private ULTRA_TORSO_DNA_POSITION = ULTRA_WEAPON_DNA_POSITION - 4;
    uint constant private ULTRA_EYES_DNA_POSITION = ULTRA_TORSO_DNA_POSITION - 3;
    uint constant private ULTRA_GLASSES_DNA_POSITION = ULTRA_EYES_DNA_POSITION - 2;
    uint constant private ULTRA_HAIR_DNA_POSITION = ULTRA_GLASSES_DNA_POSITION - 6;
    uint constant private ULTRA_MOUTH_DNA_POSITION = ULTRA_HAIR_DNA_POSITION - 3;
    uint constant private ULTRA_NOSE_DNA_POSITION = ULTRA_MOUTH_DNA_POSITION - 3;
    uint constant private ULTRA_CLOTHES_DNA_POSITION = ULTRA_NOSE_DNA_POSITION - 2;
    uint constant private ULTRA_GENDER_DNA_POSITION = ULTRA_CLOTHES_DNA_POSITION - 2;

    uint constant private ULTRA_BACKGROUND_DNA_BITMASK = uint256(0x1F);
    uint constant private ULTRA_WEAPON_DNA_BITMASK = uint256(0x3);
    uint constant private ULTRA_TORSO_DNA_BITMASK = uint256(0xF);
    uint constant private ULTRA_EYES_DNA_BITMASK = uint256(0x7);
    uint constant private ULTRA_GLASSES_DNA_BITMASK = uint256(0x3);
    uint constant private ULTRA_HAIR_DNA_BITMASK = uint256(0x3F);
    uint constant private ULTRA_MOUTH_DNA_BITMASK = uint256(0x7);
    uint constant private ULTRA_NOSE_DNA_BITMASK = uint256(0x7);
    uint constant private ULTRA_CLOTHES_DNA_BITMASK = uint256(0x3);
    uint constant private ULTRA_GENDER_DNA_BITMASK = uint256(0x3);

    /*//////////////////////////////////////////////////////////////
                        ULTRA ATTRIBUTES VALUES
    //////////////////////////////////////////////////////////////*/
    string[] background = [
        "City", "Stadium", "BG3", "BG4", "BG5", "BG6", "BG7", "BG8",
        "BG9", "BG10", "BG11", "BG12", "BG13", "BG14", "BG15", "BG16", "BG17"];
    string[] weapon = ["Gun", "Sword", "NONE"];
    string[] torso = [
        "Male Skin 1", "Male Skin 2",
        "Male Skin 3", "Male Skin 4",
        "Male Skin 5", "Male Rainbow", "Male Robot",
        "Female Skin 1", "Female Skin 2",
        "Female Skin 3", "Female Skin 4",
        "Female Skin 5", "Female Rainbow", "Female Robot"];
    string[] eyes = [
        "Male Ocean", "Male Fire", "Male Forest",
        "Female Ocean", "Female Fire", "Female Forest"];
    string[] glasses = ["White", "Black", "NONE"];
    string[] hair = [
        "Male Swept Blue", "Male Swept Red", "Male Swept Green", "Male Swept Yellow", "Male Swept White",
        "Male Half Bun Brown", "Male Half Bun Pink", "Male Half Bun Aqua", "Male Half Bun Purple", "Male Half Bun Blue",
        "Male Wavy Pink", "Male Wavy Yellow", "Male Wavy Navy", "Male Wavy Orange", "Male Wavy Blue",
        "Male Spiky Purple", "Male Spiky Orange", "Male Spiky Blue", "Male Spiky Red", "Male Spiky White",
        "Female Bangs Blue", "Female Bangs Red", "Female Bangs Green", "Female Bangs Yellow", "Female Bangs White",
        "Female Half Bun Brown", "Female Half Bun Pink", "Female Half Bun Aqua", "Female Half Bun Purple",
        "Female Half Bun Blue",
        "Female Spiky Pink", "Female Spiky Yellow", "Female Spiky Navy", "Female Spiky Orange", "Female Spiky Blue",
        "Female Wavy Purple", "Female Wavy Orange", "Female Wavy Blue", "Female Wavy Red", "Female Wavy White"];
    string[] mouth = ["Male Pink", "Male Red", "Female Pink", "Female Brown", "Female Red"];
    string[] nose = ["Male Small", "Male Medium", "Male Large", "Female Small", "Female Medium", "Female Large"];
    string[] clothes = ["Male Jacket", "Female Jacket", "NONE"];
    string[] gender = ["Male", "Female"];

    // @notice ULTRA Attributes DNA
    // @dev tokenId => Ultra DNA bits
    // Bits arrange in following order:
    // ["Background", "Weapon", "Torso", "Eyes", "Glasses", "Hair", "Mouth", "Nose", "Clothes", "gender"]
    // Bits size of each attribute:
    // [5  2  4    3   2    6    3   3   2  2]
    // Example:
    // 10001 11 1110 110 11 101000 101 110 11 10
    mapping (uint => uint) public ultraDna;

    // ULTRA Description
    string private defaultDescription;
    mapping (uint => string) public tokenDescription;

    // Forced Offline NFT address
    address public forcedOfflineAddress;

    // flag for supporting animation url or not
    bool public enableAnimationUrl;

    string public baseURI;

    /*//////////////////////////////////////////////////////////////
                               MODIFIER
    //////////////////////////////////////////////////////////////*/
    modifier onlyForcedOffline() {
        require(msg.sender == forcedOfflineAddress, "UltraMetadata: not ForceOffline");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct TokenURIParams {
        string name;
        string description;
        string background;
        string weapon;
        string torso;
        string eyes;
        string glasses;
        string hair;
        string mouth;
        string nose;
        string clothes;
        string gender;
        string imageUrl;
        string animationUrl;
    }

    /*//////////////////////////////////////////////////////////////
                            CONFIGURE LOGIC
    //////////////////////////////////////////////////////////////*/
    function setDescription(uint tokenId_, string calldata description_) public onlyForcedOffline {
        tokenDescription[tokenId_] = description_;
    }

    function setBaseURI(string memory baseURI_) public onlyForcedOffline {
        baseURI = baseURI_;
    }

    // @notice Batch update Ultra DNA
    // @dev DNA is an integer representing bits value of each attribute
    function updateDNA(uint from_, uint[] calldata dnas_) external onlyOwner {
        for (uint i = 0; i < dnas_.length; i++) {
            ultraDna[from_+i] = dnas_[i];
        }
    }

    function setForcedOfflineAddress(address forcedOfflineAddress_) external onlyOwner {
        forcedOfflineAddress = forcedOfflineAddress_;
    }

    function setDefaultDescription(string calldata defaultDescription_) external onlyOwner {
        defaultDescription = defaultDescription_;
    }

    function toggleEnableAnimationUrl() external onlyOwner {
        if (enableAnimationUrl) {
            enableAnimationUrl = false;
        } else {
            enableAnimationUrl = true;
        }
    }

    /*//////////////////////////////////////////////////////////////
                              URI LOGIC
    //////////////////////////////////////////////////////////////*/
    function tokenURI(uint256 tokenId_) public view returns (string memory) {
        require(!isEmptyString(baseURI), "no base URI");
        require(ultraDna[tokenId_] > 0, 'nonexistent token');

        string memory imageUrl = string(abi.encodePacked(baseURI, "images/", tokenId_.toString(), ".png"));
        string memory animationUrl =
        enableAnimationUrl ? string(abi.encodePacked(baseURI, "html/", tokenId_.toString())) : "";
        string memory description = tokenDescription[tokenId_];
        description = isEmptyString(description) ? defaultDescription : description;

        TokenURIParams memory params = TokenURIParams({
        name: getName(tokenId_),
        description: description,
        background: getBackground(tokenId_),
        weapon: getWeapon(tokenId_),
        torso: getTorso(tokenId_),
        eyes: getEyes(tokenId_),
        glasses: getGlasses(tokenId_),
        hair: getHair(tokenId_),
        mouth: getMouth(tokenId_),
        nose: getNose(tokenId_),
        clothes: getClothes(tokenId_),
        gender: getGender(tokenId_),
        imageUrl: imageUrl,
        animationUrl: animationUrl
        });

        return constructTokenURI(params);
    }

    function constructTokenURI(TokenURIParams memory params)
    internal
    pure
    returns (string memory)
    {
        bytes memory metadata = abi.encodePacked('{"name":"',
            params.name,
            '","description":"',
            params.description,
            '","image": "',
            params.imageUrl );

        if (!isEmptyString(params.animationUrl)) {
            metadata = abi.encodePacked(
                metadata,
                '","animation_url": "',
                params.animationUrl
            );
        }

        metadata = abi.encodePacked(
            metadata,
            abi.encodePacked(
                '","attributes":[',
                '{"trait_type": "Background", "value": "', params.background, '"},'));
        if (!compareStrings(params.weapon, "NONE")) {
            metadata = abi.encodePacked(
                metadata,
                abi.encodePacked(
                    '{"trait_type": "Weapon", "value": "', params.weapon, '"},'
                ));
        }
        metadata = abi.encodePacked(
            metadata,
            abi.encodePacked(
                '{"trait_type": "Torso", "value": "', params.torso, '"},',
                '{"trait_type": "Eyes", "value": "', params.eyes, '"},'
            ));
        if (!compareStrings(params.glasses,"NONE")) {
            metadata = abi.encodePacked(
                metadata,
                abi.encodePacked(
                    '{"trait_type": "Glasses", "value": "', params.glasses, '"},'
                ));
        }
        if (!compareStrings(params.clothes,"NONE")) {
            metadata = abi.encodePacked(
                metadata,
                abi.encodePacked(
                    '{"trait_type": "Clothes", "value": "', params.clothes, '"},'
                ));
        }
        metadata = abi.encodePacked(
            metadata,
            abi.encodePacked(
                '{"trait_type": "Hair", "value": "', params.hair, '"},',
                '{"trait_type": "Mouth", "value": "', params.mouth, '"},',
                '{"trait_type": "Nose", "value": "', params.nose, '"},',
                '{"trait_type": "Gender", "value": "', params.gender, '"}',
                ']}'));

        return string(
            abi.encodePacked(
                'data:application/json;base64,',
                Base64.encode(
                    bytes(metadata)
                )
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                         GETTER OF ATTRIBUTES
    //////////////////////////////////////////////////////////////*/
    function getBackground(uint tokenId_) public view returns (string memory) {
        uint backgroundIndex = (ultraDna[tokenId_] >> ULTRA_BACKGROUND_DNA_POSITION) & ULTRA_BACKGROUND_DNA_BITMASK;
        return background[backgroundIndex];
    }

    function getWeapon(uint tokenId_) public view returns (string memory) {
        uint weaponIndex = (ultraDna[tokenId_] >> ULTRA_WEAPON_DNA_POSITION) & ULTRA_WEAPON_DNA_BITMASK;
        return weapon[weaponIndex];
    }

    function getTorso(uint tokenId_) public view returns (string memory) {
        uint torsoIndex = (ultraDna[tokenId_] >> ULTRA_TORSO_DNA_POSITION) & ULTRA_TORSO_DNA_BITMASK;
        return torso[torsoIndex];
    }

    function getEyes(uint tokenId_) public view returns (string memory) {
        uint eyesIndex = (ultraDna[tokenId_] >> ULTRA_EYES_DNA_POSITION) & ULTRA_EYES_DNA_BITMASK;
        return eyes[eyesIndex];
    }

    function getGlasses(uint tokenId_) public view returns (string memory) {
        uint glassesIndex = (ultraDna[tokenId_] >> ULTRA_GLASSES_DNA_POSITION) & ULTRA_GLASSES_DNA_BITMASK;
        return glasses[glassesIndex];
    }

    function getHair(uint tokenId_) public view returns (string memory) {
        uint hairIndex = (ultraDna[tokenId_] >> ULTRA_HAIR_DNA_POSITION) & ULTRA_HAIR_DNA_BITMASK;
        return hair[hairIndex];
    }

    function getMouth(uint tokenId_) public view returns (string memory) {
        uint mouthIndex = (ultraDna[tokenId_] >> ULTRA_MOUTH_DNA_POSITION) & ULTRA_MOUTH_DNA_BITMASK;
        return mouth[mouthIndex];
    }

    function getNose(uint tokenId_) public view returns (string memory) {
        uint noseIndex = (ultraDna[tokenId_] >> ULTRA_NOSE_DNA_POSITION) & ULTRA_NOSE_DNA_BITMASK;
        return nose[noseIndex];
    }

    function getClothes(uint tokenId_) public view returns (string memory) {
        uint clothesIndex = (ultraDna[tokenId_] >> ULTRA_CLOTHES_DNA_POSITION) & ULTRA_CLOTHES_DNA_BITMASK;
        return clothes[clothesIndex];
    }

    function getGender(uint tokenId_) public view returns (string memory) {
        uint genderIndex = (ultraDna[tokenId_] >> ULTRA_GENDER_DNA_POSITION) & ULTRA_GENDER_DNA_BITMASK;
        return gender[genderIndex];
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function isEmptyString(string memory str) internal pure returns (bool) {
        return bytes(str).length == 0;
    }

    function getName(uint tokenId_) internal pure returns (string memory) {
        return string(abi.encodePacked("Ultra #", getPaddedString(tokenId_, 3)));
    }

    function getPaddedString(uint num, uint length) internal pure returns (string memory) {
        string memory numString = num.toString();
        uint numDigits = bytes(numString).length;
        if (numDigits >= length) {
            return numString;
        } else {
            bytes memory paddedString = new bytes(length);
            for (uint i = 0; i < length - numDigits; i++) {
                paddedString[i] = "0";
            }
            for (uint i = length - numDigits; i < length; i++) {
                paddedString[i] = bytes(numString)[i - (length - numDigits)];
            }
            return string(paddedString);
        }
    }

    function compareStrings(string memory str1, string memory str2) internal pure returns (bool) {
        return keccak256(abi.encodePacked(str1)) == keccak256(abi.encodePacked(str2));
    }

}
