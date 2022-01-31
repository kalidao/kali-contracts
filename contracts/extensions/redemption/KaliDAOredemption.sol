// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.4;

import '../../sub/KaliSubDAOtoken.sol';
import '../../libraries/SafeTransferLib.sol';
import '../../interfaces/IERC20minimal.sol';
import '../../utils/ReentrancyGuard.sol';

/// @notice Redemption contract that transfers registered tokens from Kali DAO in proportion to burnt DAO tokens.
contract KaliDAOredemption is ReentrancyGuard {
    using SafeTransferLib for address;

    /*///////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event ExtensionSet(address indexed dao, address lootToken, uint32 redemptionStarts, bool votesRedeemable);

    event ExtensionCalled(address indexed dao, address indexed member, uint256 lootToRedeem, uint256 votesToRedeem);

    event LootDeployed(address indexed dao, string name, string symbol, bool paused, address[] voters, uint256[] shares);

    /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotStarted();

    error NullDeploy();

    /*///////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable lootMaster;

    mapping(address => Redemption) public redemptions;

    struct Redemption {
        address lootToken;
        uint32 redemptionStarts;
        bool votesRedeemable;
    }

    /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address lootMaster_) {
        lootMaster = lootMaster_;
    }

    /*///////////////////////////////////////////////////////////////
                            REDEMPTION LOGIC
    //////////////////////////////////////////////////////////////*/

    function setExtension(bytes calldata extensionData) public nonReentrant virtual {
        (address lootToken, uint32 redemptionStarts, bool votesRedeemable) 
            = abi.decode(extensionData, (address, uint32, bool));

        redemptions[msg.sender] = Redemption({
            lootToken: lootToken,
            redemptionStarts: redemptionStarts,
            votesRedeemable: votesRedeemable
        });

        emit ExtensionSet(msg.sender, lootToken, redemptionStarts, votesRedeemable);
    }

    function callExtension(
        address dao, 
        address[] calldata tokensToClaim, 
        uint256 lootToRedeem,
        uint256 votesToRedeem
    ) public nonReentrant virtual {
        Redemption storage redmn = redemptions[dao];

        if (block.timestamp < redmn.redemptionStarts) revert NotStarted();

        uint256 totalSupply;

        if (redmn.lootToken != address(0)) {
            totalSupply += IERC20minimal(redmn.lootToken).totalSupply();

            IERC20minimal(redmn.lootToken).burnFrom(msg.sender, lootToRedeem);
        }
 
        if (redmn.votesRedeemable) {
            totalSupply += IERC20minimal(dao).totalSupply();

            IERC20minimal(dao).burnFrom(msg.sender, votesToRedeem);
        }

        for (uint256 i; i < tokensToClaim.length;) {
            // calculate fair share of given token for redemption
            uint256 amountToRedeem = (lootToRedeem + votesToRedeem) * 
                IERC20minimal(tokensToClaim[i]).balanceOf(dao) / 
                totalSupply;
            
            // `transferFrom` DAO to redeemer
            if (amountToRedeem != 0) {
                tokensToClaim[i]._safeTransferFrom(
                    dao, 
                    msg.sender, 
                    amountToRedeem
                );
            }

            unchecked {
                i++;
            }
        }

        emit ExtensionCalled(dao, msg.sender, lootToRedeem, votesToRedeem);
    }

    /*///////////////////////////////////////////////////////////////
                            DEPLOYER LOGIC
    //////////////////////////////////////////////////////////////*/

    function deployKaliDAOloot(
        string memory name_,
        string memory symbol_,
        bool paused_,
        address[] memory voters_,
        uint256[] memory shares_
    ) public virtual returns (KaliSubDAOtoken kaliLoot) {
        kaliLoot = KaliSubDAOtoken(_cloneAsMinimalProxy(lootMaster, name_));

        kaliLoot.init(
            name_,
            symbol_,
            paused_,
            voters_,
            shares_,
            msg.sender
        );

        redemptions[msg.sender].lootToken = address(kaliLoot);

        emit LootDeployed(msg.sender, name_, symbol_, paused_, voters_, shares_);
    }

    /// @dev modified from Aelin (https://github.com/AelinXYZ/aelin/blob/main/contracts/MinimalProxyFactory.sol)
    function _cloneAsMinimalProxy(address base, string memory name_) internal virtual returns (address clone) {
        bytes memory createData = abi.encodePacked(
            // constructor
            bytes10(0x3d602d80600a3d3981f3),
            // proxy code
            bytes10(0x363d3d373d3d3d363d73),
            base,
            bytes15(0x5af43d82803e903d91602b57fd5bf3)
        );

        bytes32 salt = keccak256(bytes(name_));

        assembly {
            clone := create2(
                0, // no value
                add(createData, 0x20), // data
                mload(createData),
                salt
            )
        }
        // if CREATE2 fails for some reason, address(0) is returned
        if (clone == address(0)) revert NullDeploy();
    }
}
