//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

contract VALU is ERC20 {

    constructor() ERC20("Valu Token", "VALU", 18){}

    function mint(address to, uint amount) public {
        _mint(to, amount);
    }

    function burn(uint amount) public {
        _burn(msg.sender, amount);
    }
    
}
