// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.4;

import '../tokens/ERC721/ERC721initializable.sol';
import '../libraries/Base64.sol';
import '../interfaces/IERC20minimal.sol';
import '../utils/NFThelper.sol';

/// @notice EIP-712-signed multi-signature contract with NFT identifiers for signers and ragequit.
/// @dev This design allows signers to transfer role - consider overriding transfers as alternative.
/// @author Modified from MultiSignatureWallet (https://github.com/SilentCicero/MultiSignatureWallet)
/// and LilGnosis (https://github.com/m1guelpf/lil-web3/blob/main/src/LilGnosis.sol)
contract ClubSig is ERC721initializable {
    /*///////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Execute(address target, uint256 value, bytes payload);
    event Govern(address[] signers, uint256 quorum);

    /*///////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NoArrayParity();
    error SigBounds();
    error InvalidSigner();
    error ExecuteFailed();
    error Forbidden();
    error NotSigner();
    error TransferFailed();

    /*///////////////////////////////////////////////////////////////
                             CLUB STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public nonce = 1;
    uint256 public quorum;
    uint256 public totalLoot;

    mapping(address => uint256) public loot;
    mapping(address => bool) public governor;

    struct Call {
        address target; 
        uint256 value;
        bytes payload;
        bool deleg;
    }

    /*///////////////////////////////////////////////////////////////
                             EIP-712 STORAGE
    //////////////////////////////////////////////////////////////*/

    struct Signature {
	    uint8 v;
	    bytes32 r;
        bytes32 s;
    }

    /*///////////////////////////////////////////////////////////////
                              INITIALIZER
    //////////////////////////////////////////////////////////////*/

    function init(
        address[] calldata signers, 
        uint256[] calldata loots, 
        uint256 quorum_,
        string calldata name_,
        string calldata symbol_,
        bool paused_
    ) public virtual {
        ERC721initializable._init(name_, symbol_, paused_);

        uint256 length = signers.length;
        if (length != loots.length) revert NoArrayParity();
        if (quorum_ > length) revert SigBounds();
        // cannot realistically overflow on human timescales
        unchecked {
            for (uint256 i = 0; i < length; i++) {
                _safeMint(signers[i], uint256(keccak256(abi.encodePacked(signers[i]))));
                totalSupply++;
                loot[signers[i]] = loots[i];
                totalLoot += loots[i];
            }
        }
        quorum = quorum_;
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();
    }

    /*///////////////////////////////////////////////////////////////
                          METADATA LOGIC
    //////////////////////////////////////////////////////////////*/

    function tokenURI(uint256 tokenId) public view override virtual returns (string memory) {
        return string(_constructTokenURI(tokenId));
    }

    function _constructTokenURI(uint256 tokenId) internal view returns (string memory) {
        address owner = ownerOf[tokenId];

        string memory metaSVG = string(
            abi.encodePacked(
                '<text dominant-baseline="middle" text-anchor="middle" fill="white" x="50%" y="90px">',
                toString(loot[owner]),
                " Loot",
                "</text>"
            )
        );
        bytes memory svg = abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" preserveAspectRatio="xMidYMid meet" style="font:14px serif"><rect width="400" height="400" fill="black" />',
            metaSVG,
            "</svg>"
        );
        bytes memory _image = abi.encodePacked(
            "data:image/svg+xml;base64,",
            Base64.encode(bytes(svg))
        );
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name":"',
                            name,
                            '", "image":"',
                            _image,
                            '", "description": "Illustrious Club member with a dynamically generated NFT showing loot weight."}'
                        )
                    )
                )
            )
        );
    }

    function toString(uint256 value) internal pure returns (string memory) {
        // @dev inspired by OraclizeAPI's implementation - MIT license -
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol
        if (value == 0) {
            return '0';
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /*///////////////////////////////////////////////////////////////
                            OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function execute(
        Call calldata call,
        Signature[] calldata sigs
    ) public virtual returns (bool success, bytes memory result) {
        // cannot realistically overflow on human timescales
        unchecked {
            bytes32 digest =
                keccak256(
                    abi.encodePacked(
                        '\x19\x01',
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256('Exec(address target,uint256 value,bytes payload,bool deleg,uint256 nonce)'),
                                call.target,
                                call.value,
                                call.payload,
                                call.deleg,
                                nonce++
                            )
                        )
                    )
                );

                address previous;

                for (uint256 i = 0; i < quorum; i++) {
                    address sigAddress = ecrecover(digest, sigs[i].v, sigs[i].r, sigs[i].s);
                    // check for key balance and duplicates
                    if (balanceOf[sigAddress] == 0 || previous >= sigAddress) revert InvalidSigner();
                    previous = sigAddress;
                }
        }
       
        if (!call.deleg) {
            (success, result) = call.target.call{value: call.value}(call.payload);
            if (!success) revert ExecuteFailed();
        } else {
            (success, result) = call.target.delegatecall(call.payload);
            if (!success) revert ExecuteFailed();
        }

        emit Execute(call.target, call.value, call.payload);
    }

    function govern(
        address[] calldata signers,
        uint256[] calldata ids, 
        uint256[] calldata loots,
        bool[] calldata mints,
        uint256 quorum_
    ) public virtual {
        if (msg.sender != address(this) || !governor[msg.sender]) revert Forbidden();

        uint256 length = signers.length;
        if (length != ids.length || length != mints.length) revert NoArrayParity();
        // cannot realistically overflow on human timescales
        unchecked {
            for (uint256 i = 0; i < length; i++) {
                if (mints[i]) {
                    _safeMint(signers[i], ids[i]);
                    totalSupply++;
                } else {
                    _burn(ids[i]);
                    totalSupply--;
                }
                loot[signers[i]] += loots[i];
            }
        }
        if (quorum_ > totalSupply) revert SigBounds();
        quorum = quorum_;

        emit Govern(signers, quorum_);
    }

    function flipPause() public virtual {
        if (msg.sender != address(this) || !governor[msg.sender]) revert Forbidden();

        ERC721initializable._flipPause();
    }

    function flipGovernor(address account) public virtual {
        if (msg.sender != address(this) || !governor[msg.sender]) revert Forbidden();

        governor[account] = !governor[account];
    }

    function governorExecute(Call calldata call) public returns (bool success, bytes memory result) {
        if (!governor[msg.sender]) revert Forbidden();

        if (!call.deleg) {
            (success, result) = call.target.call{value: call.value}(call.payload);
            if (!success) revert ExecuteFailed();
        } else {
            (success, result) = call.target.delegatecall(call.payload);
            if (!success) revert ExecuteFailed();
        }
    }

    /*///////////////////////////////////////////////////////////////
                            ASSET MGMT
    //////////////////////////////////////////////////////////////*/

    receive() external payable {}

    function ragequit(address[] calldata assets, uint256 lootToBurn) public virtual {
        uint256 length = assets.length;
        // cannot realistically overflow on human timescales
        unchecked {
            for (uint256 i; i < length; i++) {
                if (i != 0) {
                    require(assets[i] > assets[i - 1], '!order');
                }
            }
        }

        uint256 lootTotal = totalLoot;

        loot[msg.sender] -= lootToBurn;
        totalLoot -= lootToBurn;

        for (uint256 i; i < length;) {
            // calculate fair share of given assets for redemption
            uint256 amountToRedeem = lootToBurn * IERC20minimal(assets[i]).balanceOf(address(this)) / 
                lootTotal;
            // transfer to redeemer
            if (amountToRedeem != 0)
                _safeTransfer(assets[i], msg.sender, amountToRedeem);
            // cannot realistically overflow on human timescales
            unchecked {
                i++;
            }
        }
    }

    function _safeTransfer(
        address token,
        address to,
        uint256 amount
    ) internal {
        bool callStatus;
        assembly {
            // get a pointer to some free memory
            let freeMemoryPointer := mload(0x40)
            // write the abi-encoded calldata to memory piece by piece:
            mstore(freeMemoryPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000) // begin with the function selector
            mstore(add(freeMemoryPointer, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // mask and append the "to" argument
            mstore(add(freeMemoryPointer, 36), amount) // finally append the "amount" argument - no mask as it's a full 32 byte value
            // call the token and store if it succeeded or not
            // we use 68 because the calldata length is 4 + 32 * 2
            callStatus := call(gas(), token, 0, freeMemoryPointer, 68, 0, 0)
        }
        if (!_didLastOptionalReturnCallSucceed(callStatus)) revert TransferFailed();
    }

    function _didLastOptionalReturnCallSucceed(bool callStatus) internal pure returns (bool success) {
        assembly {
            // get how many bytes the call returned
            let returnDataSize := returndatasize()
            // if the call reverted:
            if iszero(callStatus) {
                // copy the revert message into memory
                returndatacopy(0, 0, returnDataSize)
                // revert with the same message
                revert(0, returnDataSize)
            }
            switch returnDataSize
            case 32 {
                // copy the return data into memory
                returndatacopy(0, 0, returnDataSize)
                // set success to whether it returned true
                success := iszero(iszero(mload(0)))
            }
            case 0 {
                // there was no return data
                success := 1
            }
            default {
                // it returned some malformed input
                success := 0
            }
        }
    }
}
