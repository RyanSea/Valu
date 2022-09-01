//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "solmate/tokens/ERC20.sol";

import "Monarchy/";

contract VALU is ERC20, Monarchy {

    constructor() ERC20("Valu Token", "VALU", 18) Monarchy(msg.sender){}

    function mint(address to, uint amount) public ruled {
        _mint(to, amount);
    }

    function burn(uint amount) public {
        _burn(msg.sender, amount);
    }
    
}
