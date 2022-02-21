// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.4;

import '../../libraries/SafeTransferLib.sol';
import '../../interfaces/IERC20minimal.sol';
import '../../utils/ReentrancyGuard.sol';

/// @notice Redemption contract that transfers registered tokens from Kali DAO in proportion to burnt DAO tokens.
contract KaliDAOredemption is ReentrancyGuard {
    using SafeTransferLib for address;

    event ExtensionSet(address indexed dao, address[] tokens, uint256 indexed redemptionStart);

    event ExtensionCalled(address indexed dao, address indexed member, uint256 indexed amountBurned);

    event TokensAdded(address indexed dao, address[] tokens);

    event TokensRemoved(address indexed dao, uint256[] tokenIndex);

    error NullTokens();

    error NotStarted();

    mapping(address => address[]) public redeemables;

    mapping(address => uint256) public redemptionStarts;

    function getRedeemables(address dao) public view virtual returns (address[] memory tokens) {
        tokens = redeemables[dao];
    }

    function setExtension(bytes calldata extensionData) public nonReentrant virtual {
        (address[] memory tokens, uint256 redemptionStart) = abi.decode(extensionData, (address[], uint256));

        if (tokens.length == 0) revert NullTokens();

        // if redeemables are already set, this call will be interpreted as reset
        if (redeemables[msg.sender].length != 0) delete redeemables[msg.sender];
        
        // cannot realistically overflow on human timescales
        unchecked {
            for (uint256 i; i < tokens.length; i++) {
                redeemables[msg.sender].push(tokens[i]);
            }
        }

        redemptionStarts[msg.sender] = redemptionStart;

        emit ExtensionSet(msg.sender, tokens, redemptionStart);
    }

    function callExtension(
        address account, 
        uint256 amount, 
        bytes calldata
    ) public nonReentrant virtual returns (bool mint, uint256 amountOut) {
        if (block.timestamp < redemptionStarts[msg.sender]) revert NotStarted();

        for (uint256 i; i < redeemables[msg.sender].length;) {
            // calculate fair share of given token for redemption
            uint256 amountToRedeem = amount * 
                IERC20minimal(redeemables[msg.sender][i]).balanceOf(msg.sender) / 
                IERC20minimal(msg.sender).totalSupply();
            
            // `transferFrom` DAO to redeemer
            if (amountToRedeem != 0) {
                address(redeemables[msg.sender][i])._safeTransferFrom(
                    msg.sender, 
                    account, 
                    amountToRedeem
                );
            }

            // cannot realistically overflow on human timescales
            unchecked {
                i++;
            }
        }

        // placeholder values to conform to interface and disclaim mint
        (mint, amountOut) = (false, amount);

        emit ExtensionCalled(msg.sender, account, amount);
    }

    function addTokens(address[] calldata tokens) public nonReentrant virtual {
        // cannot realistically overflow on human timescales
        unchecked {
            for (uint256 i; i < tokens.length; i++) {
                redeemables[msg.sender].push(tokens[i]);
            }
        }

        emit TokensAdded(msg.sender, tokens);
    }

    function removeTokens(uint256[] calldata tokenIndex) public nonReentrant virtual {
        for (uint256 i; i < tokenIndex.length; i++) {
            // move last token to replace indexed spot and pop array to remove last token
            redeemables[msg.sender][tokenIndex[i]] = 
                redeemables[msg.sender][redeemables[msg.sender].length - 1];

            redeemables[msg.sender].pop();
        }

        emit TokensRemoved(msg.sender, tokenIndex);
    }
}
