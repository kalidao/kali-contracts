// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.4;

import "../ERC721.sol";

/// @notice Public NFT minter for Kali DAO.
abstract contract KaliNFT is ERC721 {
    constructor(string memory name_, string memory symbol_)
        ERC721(name_, symbol_)
    {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function burn(uint256 tokenId) external {
        if (msg.sender != ownerOf[tokenId]) revert NotOwner();

        _burn(tokenId);
    }
}
