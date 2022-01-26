// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.4;

import '../../libraries/SafeTransferLib.sol';
import '../../interfaces/IERC20minimal.sol';
import '../../utils/ReentrancyGuard.sol';

/// @notice Redemption contract that transfers registered tokens from Kali DAO in proportion to burnt DAO tokens.
contract KaliDAOredemption is ReentrancyGuard {
    using SafeTransferLib for address;

    event ExtensionSet(address indexed dao, address[] redemptionTokens, uint32 redemptionStarts, bool votesRedeemable);

    event ExtensionCalled(address indexed dao, address indexed member, uint256 indexed amountBurned);

    error NotStarted();

    mapping(address => Redemption) public redemptions;

    struct Redemption {
        address[] redemptionTokens;
        uint32 redemptionStarts;
        bool votesRedeemable;
    }

    function getRedeemables(address dao) public view virtual returns (address[] memory) {
        return redemptions[dao].redemptionTokens;
    }

    function setExtension(bytes calldata extensionData) public nonReentrant virtual {
        (address[] memory redemptionTokens, uint32 redemptionStarts, bool votesRedeemable) 
            = abi.decode(extensionData, (address[], uint32, bool));

        redemptions[msg.sender] = Redemption({
            redemptionTokens: redemptionTokens,
            redemptionStarts: redemptionStarts,
            votesRedeemable: votesRedeemable
        });

        emit ExtensionSet(msg.sender, redemptionTokens, redemptionStarts, votesRedeemable);
    }

    function callExtension(
        address dao, 
        address[] calldata tokensToRedeem, 
        uint256[] calldata redemptionAmounts,
        uint256 votesToRedeem
    ) public nonReentrant virtual {
        Redemption storage redmn = redemptions[dao];

        if (block.timestamp < redmn.redemptionStarts) revert NotStarted();

        uint256 amount;

        uint256 totalSupply;

        if (redmn.votesRedeemable) {
            IERC20minimal(dao).burnFrom(msg.sender, votesToRedeem);

            amount += votesToRedeem;

            totalSupply += IERC20minimal(dao).totalSupply();
        }

        if (tokensToRedeem.length != 0) {
            for (uint256 i; i < redmn.redemptionTokens.length;) {
                IERC20minimal(tokensToRedeem[i]).burnFrom(msg.sender, redemptionAmounts[i]);
                
                amount += redemptionAmounts[i];

                totalSupply += IERC20minimal(tokensToRedeem[i]).totalSupply();

                unchecked {
                    i++;
                }
            }
        }

        for (uint256 i; i < tokensToRedeem.length;) {
            // calculate fair share of given token for redemption
            uint256 amountToRedeem = amount * 
                IERC20minimal(tokensToRedeem[i]).balanceOf(dao) / 
                totalSupply;
            
            // `transferFrom` DAO to redeemer
            if (amountToRedeem != 0) {
                tokensToRedeem[i]._safeTransferFrom(
                    dao, 
                    msg.sender, 
                    amountToRedeem
                );
            }

            unchecked {
                i++;
            }
        }


        emit ExtensionCalled(dao, msg.sender, amount);
    }
}
