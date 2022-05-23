// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.4;

import '../../libraries/SafeTransferLib.sol';
import '../../interfaces/IERC20minimal.sol';
import '../../interfaces/IKaliAccessManager.sol';
import '../../utils/ReentrancyGuard.sol';

/// @notice Crowdsale contract that receives ETH or tokens to mint registered DAO tokens, including merkle whitelisting.
contract KaliDAOlinearCurve is ReentrancyGuard {
    using SafeTransferLib for address;

    event ExtensionSet(
        uint256 indexed listId,
        uint256 startingPrice,
        uint96 purchaseLimit,
        uint96 curve,
        uint32 saleEnds
    );

    event ExtensionCalled(address indexed dao, address indexed member, uint256 indexed amountOut);

    error SaleEnded();

    error NotWhitelisted();

    error NotPrice();

    error PurchaseLimit();

    IKaliAccessManager public immutable accessManager;

    mapping(address => Crowdsale) public crowdsales;

    struct Crowdsale {
        uint256 listId;
        uint256 startingPrice;
        uint96 purchaseLimit;
        uint96 amountPurchased;
        uint96 curve;
        uint32 saleEnds;
    }

    constructor(IKaliAccessManager accessManager_) {
        accessManager = accessManager_;
    }

    function setExtension(bytes calldata extensionData) public nonReentrant virtual {
        (
            uint256 listId,
            uint256 startingPrice,
            uint96 purchaseLimit,
            uint96 curve,
            uint32 saleEnds
        )
            = abi.decode(extensionData, (uint256, uint256, uint96, uint96, uint32));

        crowdsales[msg.sender] = Crowdsale({
            listId: listId,
            startingPrice: startingPrice,
            purchaseLimit: purchaseLimit,
            amountPurchased: 0,
            curve: curve,
            saleEnds: saleEnds
        });

        emit ExtensionSet(listId, startingPrice, purchaseLimit, curve, saleEnds);
    }

    function callExtension(
        address account,
        uint256 amount,
        bytes calldata
    ) public payable nonReentrant virtual returns (bool mint, uint256 amountOut) {
        Crowdsale storage sale = crowdsales[msg.sender];

        if (block.timestamp > sale.saleEnds) revert SaleEnded();

        if (sale.listId != 0)
            if (!accessManager.whitelistedAccounts(sale.listId, account)) revert NotWhitelisted();

        uint256 estPrice = estimatePrice(sale, amount);

        if (msg.value != estPrice) revert NotPrice();

        amountOut = amount;

        if (sale.amountPurchased + amountOut > sale.purchaseLimit) revert PurchaseLimit();

        // send ETH to DAO
        msg.sender._safeTransferETH(msg.value);

        sale.amountPurchased += uint96(amountOut);

        mint = true;

        emit ExtensionCalled(msg.sender, account, amountOut);
    }

    function estimatePrice(Crowdsale memory sale, uint256 amount) public view returns (uint256) {
        uint256 start = IERC20minimal(msg.sender).totalSupply();

        uint256 end = amount;

        uint endIntegral = (sale.startingPrice * end) + (end**2 / (sale.curve * 2));

        uint startIntegral = (sale.startingPrice * start) + (start**2 / (sale.curve * 2));

        uint estTotal = endIntegral - startIntegral;

        return estTotal;
    }
}
