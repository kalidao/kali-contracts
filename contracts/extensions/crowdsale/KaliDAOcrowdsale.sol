// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.4;

import '../../libraries/SafeTransferLib.sol';
import '../../interfaces/IKaliShareManager.sol';
import '../../interfaces/IKaliAccessManager.sol';
import '../../utils/ReentrancyGuard.sol';

/// @notice Crowdsale contract that receives ETH or tokens to mint registered DAO tokens, including merkle whitelisting.
contract KaliDAOcrowdsale is ReentrancyGuard {
    using SafeTransferLib for address;

    event ExtensionSet(
        address indexed dao, 
        uint256 listId, 
        address purchaseToken, 
        uint8 purchaseMultiplier, 
        uint96 purchaseLimit, 
        uint32 saleEnds, 
        string details
    );

    event ExtensionCalled(address indexed dao, address indexed purchaser, uint256 amountOut);

    error NullMultiplier();

    error SaleEnded();

    error NotListed();

    error PurchaseLimit();
    
    IKaliAccessManager private immutable accessManager;

    mapping(address => Crowdsale) public crowdsales;

    struct Crowdsale {
        uint256 listId;
        address purchaseToken;
        uint8 purchaseMultiplier;
        uint96 purchaseLimit;
        uint96 amountPurchased;
        uint32 saleEnds;
        string details;
    }

    constructor(IKaliAccessManager accessManager_) {
        accessManager = accessManager_;
    }

    function setExtension(bytes calldata extensionData) public nonReentrant virtual {
        (uint256 listId, address purchaseToken, uint8 purchaseMultiplier, uint96 purchaseLimit, uint32 saleEnds, string memory details) 
            = abi.decode(extensionData, (uint256, address, uint8, uint96, uint32, string));
        
        if (purchaseMultiplier == 0) revert NullMultiplier();

        crowdsales[msg.sender] = Crowdsale({
            listId: listId,
            purchaseToken: purchaseToken,
            purchaseMultiplier: purchaseMultiplier,
            purchaseLimit: purchaseLimit,
            amountPurchased: 0,
            saleEnds: saleEnds,
            details: details
        });

        emit ExtensionSet(msg.sender, listId, purchaseToken, purchaseMultiplier, purchaseLimit, saleEnds, details);
    }

    function callExtension(address dao, uint256 amount) public payable nonReentrant virtual returns (uint256 amountOut) {
        Crowdsale storage sale = crowdsales[dao];

        if (block.timestamp > sale.saleEnds) revert SaleEnded();

        if (sale.listId != 0) 
            if (!accessManager.listedAccounts(sale.listId, msg.sender)) revert NotListed();

        if (sale.purchaseToken == address(0)) {
            amountOut = msg.value * sale.purchaseMultiplier;

            if (sale.amountPurchased + amountOut > sale.purchaseLimit) revert PurchaseLimit();

            // send ETH to DAO
            dao._safeTransferETH(msg.value);

            sale.amountPurchased += uint96(amountOut);

            IKaliShareManager(dao).mintShares(msg.sender, amountOut);
        } else {
            // send tokens to DAO
            sale.purchaseToken._safeTransferFrom(msg.sender, dao, amount);

            amountOut = amount * sale.purchaseMultiplier;

            if (sale.amountPurchased + amountOut > sale.purchaseLimit) revert PurchaseLimit();

            sale.amountPurchased += uint96(amountOut);
            
            IKaliShareManager(dao).mintShares(msg.sender, amountOut);
        }

        emit ExtensionCalled(dao, msg.sender, amountOut);
    }
}
