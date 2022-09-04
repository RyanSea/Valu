// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "solmate/tokens/ERC20.sol";

import "Monarchy/";

contract EngagementToken is ERC20 /* , Monarchy */ {

    constructor(string memory name, string memory symbol)
        ERC20(name, symbol, 18) /* Monarchy(msg.sender )*/ { 
    }


    function mint(address to, uint amount) public /* ruled */ {
        _mint(to, amount);
    }

    /// @notice burns token
    /// @dev used for claiming $VALU
    function burn(address from, uint amount) public /* ruled */ {
        _burn(from, amount);
    }

    /// @notice sets allowance to sphere
    /// @dev only used by sphere for staking to improve UX
    function allow(address user, uint amount) public /* ruled */ {
        allowance[user][msg.sender] += amount;
    }
    
}