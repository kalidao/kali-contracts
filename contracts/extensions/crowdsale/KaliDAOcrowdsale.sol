// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.4;

import '../../libraries/SafeTransferLib.sol';
import '../../interfaces/IKaliDAOextension.sol';
import '../../interfaces/IKaliWhitelistManager.sol';
import '../../utils/ReentrancyGuard.sol';

/// @notice Crowdsale contract that receives ETH or tokens to mint registered DAO tokens, including merkle whitelisting.
contract KaliDAOcrowdsale is ReentrancyGuard {
    using SafeTransferLib for address;

    event ExtensionSet(
        address dao, 
        uint256 listId, 
        address purchaseToken, 
        uint8 purchaseMultiplier, 
        uint96 purchaseLimit, 
        uint96 saleGoal,
        uint32 saleEnds
    );

    event ExtensionCalled(address indexed dao, address indexed member, uint256 indexed amountOut);

    error NullMultiplier();

    error SaleEnded();

    error NotWhitelisted();

    error PurchaseLimit();

    error GoalMet();
    
    IKaliWhitelistManager public immutable whitelistManager;

    mapping(address => Crowdsale) public crowdsales;

    mapping(address => mapping(address => uint256)) public purchases;

    struct Crowdsale {
        uint256 listId;
        address purchaseToken;
        uint8 purchaseMultiplier;
        uint96 purchaseLimit;
        uint96 amountPurchased;
        uint96 saleGoal;
        uint32 saleEnds;
    }

    constructor(IKaliWhitelistManager whitelistManager_) {
        whitelistManager = whitelistManager_;
    }

    function setExtension(bytes calldata extensionData) public nonReentrant virtual {
        (uint256 listId, address purchaseToken, uint8 purchaseMultiplier, uint96 purchaseLimit, uint96 saleGoal, uint32 saleEnds) 
            = abi.decode(extensionData, (uint256, address, uint8, uint96, uint96, uint32));
        
        if (purchaseMultiplier == 0) revert NullMultiplier();

        crowdsales[msg.sender] = Crowdsale({
            listId: listId,
            purchaseToken: purchaseToken,
            purchaseMultiplier: purchaseMultiplier,
            purchaseLimit: purchaseLimit,
            amountPurchased: 0,
            saleGoal: saleGoal,
            saleEnds: saleEnds
        });

        emit ExtensionSet(msg.sender, listId, purchaseToken, purchaseMultiplier, purchaseLimit, saleGoal, saleEnds);
    }

    function callExtension(address dao, uint256 amount) public payable nonReentrant virtual returns (uint256 amountOut) {
        Crowdsale storage sale = crowdsales[dao];

        bytes memory extensionData = abi.encode(true);

        if (block.timestamp > sale.saleEnds) revert SaleEnded();

        if (sale.listId != 0) 
            if (!whitelistManager.whitelistedAccounts(sale.listId, msg.sender)) revert NotWhitelisted();

        if (sale.purchaseToken == address(0)) {
            amountOut = msg.value * sale.purchaseMultiplier;

            if (purchases[dao][msg.sender] + amountOut > sale.purchaseLimit) revert PurchaseLimit();

            if (sale.amountPurchased + amountOut > sale.saleGoal) revert GoalMet();

            // send ETH to DAO
            dao._safeTransferETH(msg.value);

            sale.amountPurchased += uint96(amountOut);

            IKaliDAOextension(dao).callExtension(msg.sender, amountOut, extensionData);
        } else {
            // send tokens to DAO
            sale.purchaseToken._safeTransferFrom(msg.sender, dao, amount);

            amountOut = amount * sale.purchaseMultiplier;

            if (purchases[dao][msg.sender] + amountOut > sale.purchaseLimit) revert PurchaseLimit();

            if (sale.amountPurchased + amountOut > sale.saleGoal) revert GoalMet();

            sale.amountPurchased += uint96(amountOut);

            IKaliDAOextension(dao).callExtension(msg.sender, amountOut, extensionData);
        }

        emit ExtensionCalled(msg.sender, dao, amountOut);
    }
}
