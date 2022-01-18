// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.4;

/// @notice ETH dispersal contract.
contract DropETH { 
    event ETHDropped(string indexed message);
    
    uint256 public amount;
    
    address payable[] public recipients;

    function dropETH(address payable[] calldata recipients_, string calldata message) public payable virtual {
        recipients = recipients_;
	
        amount = msg.value / recipients.length;

        // cannot realistically overflow on human timescales
	    unchecked {
            for (uint256 i = 0; i < recipients.length; i++)
	     	    recipients[i].transfer(amount);
        }
	
        emit ETHDropped(message);
    }

    receive() external payable virtual {}
}
