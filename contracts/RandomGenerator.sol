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

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "./interfaces/IRandomGenerator.sol";
import "./interfaces/IRandomConsumer.sol";

contract RandomGenerator is VRFConsumerBaseV2, ConfirmedOwner, AccessControlEnumerable, IRandomGenerator {
    bytes32 public constant RND_CONSUMER_ROLE = keccak256("CONSUMER_ROLE");
    struct RandomRequest {
        address requester;
        address user;
        uint tokenId;
        bool fulfilled;
        bool exists;
    }
    /*//////////////////////////////////////////////////////////////
                          CHAINLINK VRF CONFIG
    //////////////////////////////////////////////////////////////*/
    VRFCoordinatorV2Interface COORDINATOR;
    uint64 subscriptionId;
    bytes32 internal keyHash;
    uint32 defaultCallbackGasLimit;

    /*//////////////////////////////////////////////////////////////
                            RNG REQUEST STATE
    //////////////////////////////////////////////////////////////*/
    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;
    mapping(uint => RandomRequest) private _requestIdToRequest;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(uint64 subscriptionId_, address vrfCoordinator_, bytes32 keyHash_, uint32 defaultCallbackGasLimit_)
    VRFConsumerBaseV2(vrfCoordinator_)
    ConfirmedOwner(msg.sender) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator_);
        keyHash = keyHash_;
        subscriptionId = subscriptionId_;
        defaultCallbackGasLimit = defaultCallbackGasLimit_;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /*//////////////////////////////////////////////////////////////
                               RNG LOGIC
    //////////////////////////////////////////////////////////////*/
    function requestRandomNumber(uint256 tokenId_, address user_) public {
        requestRandomNumber(tokenId_, user_, defaultCallbackGasLimit);
    }

    function requestRandomNumber(uint256 tokenId_, address user_, uint32 callbackGasLimit_) public {
        require(hasRole(RND_CONSUMER_ROLE, _msgSender()), "RandomGenerator: must have consumer role to request");
        require(user_ != address(0), "RandomGenerator: no user");

        uint256 _requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            3, callbackGasLimit_, 1
        );

        RandomRequest storage _request = _requestIdToRequest[_requestId];
        _request.tokenId = tokenId_;
        _request.user = user_;
        _request.requester = _msgSender();
        _request.fulfilled = false;
        _request.exists = true;

        requestIds.push(_requestId);
        lastRequestId = _requestId;
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        require(_requestIdToRequest[_requestId].exists, "request not found");
        RandomRequest storage _request = _requestIdToRequest[_requestId];
        _request.fulfilled = true;
        uint256 randomness_ = _randomWords[0];

        if (randomness_ == uint256(0)) {
            randomness_ = uint256(1);
        }

        IRandomConsumer _consumer = IRandomConsumer(_request.requester);
        _consumer.runFulfillRandomness(_request.tokenId, _request.user, randomness_);
    }

    /*//////////////////////////////////////////////////////////////
                                ADMIN LOGIC
    //////////////////////////////////////////////////////////////*/
    function pullFunds(address tokenAddress_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (tokenAddress_ == address(0)) {
            payable(_msgSender()).transfer(address(this).balance);
        } else {
            IERC20 token = IERC20(tokenAddress_);
            token.transfer(_msgSender(), token.balanceOf(address(this)));
        }
    }

    function transferAdmin(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(DEFAULT_ADMIN_ROLE, account);
        revokeRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function setDefaultCallbackGasLimit(uint32 callbackGasLimit_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        defaultCallbackGasLimit = callbackGasLimit_;
    }
}
