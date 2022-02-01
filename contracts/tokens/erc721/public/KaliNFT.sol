// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.4;

import "../ERC721.sol";

/// @notice Public NFT minter for Kali DAO.
contract KaliNFT is ERC721 {
    constructor(string memory name_, string memory symbol_)
        ERC721(name_, symbol_)
    {}
    
    function tokenURI(uint256) public view override virtual returns (string memory) {
        return "PLACEHOLDER";
    }

    function mint(address to, uint256 tokenId) public virtual {
        _mint(to, tokenId);
    }

    function burn(uint256 tokenId) public virtual {
        if (msg.sender != ownerOf[tokenId]) revert NotOwner();

        _burn(tokenId);
    }
}
