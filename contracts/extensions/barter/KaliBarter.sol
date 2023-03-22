// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.10;

interface IERC721 {
    function approve(address to, uint256 tokenId) external;
    
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    function ownerOf(uint256 tokenId) external view returns (address owner);
}

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);
}

/// @notice Kali owner share manager interface
interface IKaliShareManager {
    function mintShares(address to, uint256 amount) external payable;

    function burnShares(address from, uint256 amount) external payable;
}

struct Offer {
    address by;
    uint40 deadline;
    bool active;
    bool accepted;
    bool bid;
    bool nft;
    address token;
    uint256 value;
}

struct Consideration {
    bool nft;
    address token;
    uint256 value;
}

/// @title KaliBarter
/// @notice Barter is a owner-managed marketplace that atomic swaps digital assets.
/// @author audsssy.eth 
contract KaliBarter {
    
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------


    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error InvalidOffer();
    
    error InvalidConsideration();

    error InvalidAcceptance();

    error InvalidRevocation();

    error TransferFailed();

    error ApprovalFailed();

    error ExpiredOffer();

    error StaleOffer();

    error NothingToBargain();

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------
    
    address public immutable owner;
    
    uint256 offerId;

    mapping(uint256 => Offer) public offers;

    mapping(uint256 => Consideration) public considerations;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address _owner) payable {
        owner = _owner;
    }

    /// -----------------------------------------------------------------------
    /// Barter Logic
    /// -----------------------------------------------------------------------

    function makeOffer(
        Offer calldata offer, 
        Consideration calldata consideration
    ) external payable {
        if (
            offer.token == address(0) || 
            offer.value == 0 || 
            offer.deadline == 0
        ) revert InvalidOffer();
        
        if (offer.bid) {
            if (consideration.value == 0) revert InvalidConsideration();
            
            considerations[offerId] = Consideration({
                nft: consideration.nft,
                token: consideration.token,
                value: consideration.value
            });
            
            bool success = bargain(offerId, msg.sender, address(this), consideration);
            if (!success) revert NothingToBargain();
        } else {
            if (consideration.value != 0) {
                considerations[offerId] = Consideration({
                    nft: consideration.nft,
                    token: consideration.token,
                    value: consideration.value
                });
            }
        }

        offers[offerId] = Offer({
            by: msg.sender,
            deadline: offer.deadline,
            active: offer.active,
            accepted: false,
            bid: offer.bid,
            nft: offer.nft,
            token: offer.token,
            value: offer.value
        });

        unchecked {
            ++offerId;
        }
    }

    function revoke(uint256 _offerId, Consideration calldata consideration) external payable {
        Offer memory _offer = offers[_offerId];

        if (_offer.accepted || _offer.deadline < block.timestamp) revert InvalidRevocation();

        if (_offer.bid) {
            // Return consideration
            bool success = bargain(_offerId, address(this), msg.sender, consideration);
            if (!success) revert NothingToBargain();
        }

        delete offers[_offerId];
    }

    function accept(uint256 _offerId, Consideration calldata consideration) external payable {
        Offer memory _offer = offers[_offerId];
        if (_offer.deadline < block.timestamp) revert ExpiredOffer();
        if (_offer.by == msg.sender) revert InvalidAcceptance(); // No wash trading

        bool success;

        // Check offer originator, owner or User
        if (_offer.by == owner) {
            // Check offer type, bid or ask 
            if (_offer.bid) {
                // User accepts bid offer
                success = bargain(_offerId, address(this), msg.sender, consideration);
                if (!success) revert NothingToBargain();

                if (_offer.nft) {
                    IERC721(_offer.token).safeTransferFrom(msg.sender, _offer.by, _offer.value);
                } else {
                    (success) = IERC20(_offer.token).transferFrom(msg.sender, _offer.by, _offer.value);
                    if (!success) revert TransferFailed();
                }
            } else {
                // User accepts ask offer
                success = bargain(_offerId, msg.sender, _offer.by, consideration);
                if (!success) revert NothingToBargain();

                if (_offer.nft) {
                    if (IERC721(_offer.token).ownerOf(_offer.value) !=  _offer.by) revert StaleOffer();
                    IERC721(_offer.token).safeTransferFrom(_offer.by, msg.sender, _offer.value);
                } else if (_offer.token == _offer.by) {
                    IKaliShareManager(_offer.token).mintShares(msg.sender, _offer.value);
                } else {
                    if (IERC20(_offer.token).balanceOf(_offer.by) < _offer.value) revert StaleOffer();
                    (success) = IERC20(_offer.token).transferFrom(_offer.by, msg.sender, _offer.value);
                    if (!success) revert TransferFailed();
                }
            }
        } else {
            // Check offer type, bid or ask 
            if (_offer.bid) {
                // owner accepts bid offer
                success = bargain(_offerId, address(this), owner, consideration);
                if (!success) revert NothingToBargain();

                if (_offer.nft) {
                    IERC721(_offer.token).safeTransferFrom(owner, _offer.by, _offer.value);
                } else {
                    (success) = IERC20(_offer.token).transferFrom(owner, _offer.by, _offer.value);
                    if (!success) revert TransferFailed();
                }
            } else {
                // owner accepts ask offer
                success = bargain(_offerId, owner, _offer.by, consideration);
                if (!success) revert NothingToBargain();

                if (_offer.nft) {
                    if (IERC721(_offer.token).ownerOf(_offer.value) !=  _offer.by) revert StaleOffer();
                    IERC721(_offer.token).safeTransferFrom(_offer.by, owner, _offer.value);
                } else if (_offer.token == owner) {
                    IKaliShareManager(_offer.token).burnShares(_offer.by, _offer.value);
                } else {
                    if (IERC20(_offer.token).balanceOf(_offer.by) < _offer.value) revert StaleOffer();
                    (success) = IERC20(_offer.token).transferFrom(_offer.by, owner, _offer.value);
                    if (!success) revert TransferFailed();
                }
            }
        }

        offers[_offerId].accepted = true;
    }

    function bargain(uint256 _offerId, address from, address to, Consideration calldata consideration) internal returns (bool) {

        bool success;
        // Check if Consideration is present with Acceptance
        if (consideration.value == 0) {
            Consideration memory _consideration = considerations[_offerId];
            
            // Check if Consideration is present with Offer
            if (_consideration.value == 0){
                // If Consideration is absent, then NothingToBargain() 
                return false;
            }

            if (_consideration.nft) {
                IERC721(_consideration.token).safeTransferFrom(from, to, _consideration.value);
            } else {
                (success) = IERC20(_consideration.token).transfer(to, _consideration.value);
                if (!success) revert TransferFailed();
            }
            return true;
        } else {
            if (consideration.nft) {
                IERC721(consideration.token).safeTransferFrom(from, to, consideration.value);
            } else {
                (success) = IERC20(consideration.token).transfer(to, consideration.value);
                if (!success) revert TransferFailed();
            }
            return true;
        }

    }
}
