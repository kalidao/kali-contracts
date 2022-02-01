// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.4;

interface IReentrantMock {
    function callExtension(
        address extension, 
        uint256 amount, 
        bytes calldata extensionData
    ) external payable returns (bool mint, uint256 amountOut);
}

/// @notice Mock contract for reentrancy attack simulation.
contract ReentrantMock {
    function callExtensionMock(IReentrantMock dao) public virtual {
        dao.callExtension(address(this), 10, "");
    }

    function callExtension(address, uint256, bytes memory) public virtual returns (bool mint, uint256 amountOut) {
        callExtensionMock(IReentrantMock(msg.sender));
        mint = true;
        amountOut = 100;
    }

    fallback() external virtual {}
}
