// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./Utils.sol";
import "forge-std/console2.sol";

import "src/Sphere/Sphere.sol";
import "src/Sphere/EngagementToken.sol";
import "src/VALU.sol";

contract SphereTest is Test {
    Utils internal utils;
    address payable[] internal users;

    Sphere sphere;
    EngagementToken token; 
    VALU valu;

    uint decimals = 10 ** 18;

    function setUp() public {
        utils = new Utils();
        users = utils.createUsers(4);

        vm.label(users[0], "Ryan");
        vm.label(users[1], "Devon");
        vm.label(users[2], "Vick");
        vm.label(users[3], "Jordan");

        valu = new VALU();
        token = new EngagementToken('My DAO Token','TOKEN');
        sphere = new Sphere(token, valu);
        console.log("SENDER",msg.sender);
    }

    function testTokens() public { 
        assertEq(address(sphere.token()), address(token));
        assertEq(address(sphere.valu()), address(valu));
        assertEq(sphere.name(), string(abi.encodePacked(unicode"🤍-", token.name())));
        assertEq(sphere.symbol(), string(abi.encodePacked(unicode"🤍", token.symbol())));
    }

    function testLogin() public {
        sphere.authenticate(1, users[0]);
        (address _ryan, , ) = sphere.user(1);
        assertEq(_ryan, users[0]);
    }

    function testPowerDown() public {
        sphere.authenticate(1, users[0]);

        assertEq(sphere.balanceOf(users[0]), 500 * decimals);

        sphere.powerDown(1, 350 * decimals);

        assertEq(token.balanceOf(users[0]), 350 * decimals);
        assertEq(sphere.balanceOf(users[0]), 150 * decimals);
    }

    function testPowerUp() public {
        testPowerDown();

        vm.prank(users[0]);
        token.approve(address(sphere), 300 * decimals);
        vm.stopPrank();
        
        sphere.powerUp(1, 150 * decimals);
    
        assertEq(sphere.balanceOf(users[0]), 300 * decimals);

        assertEq(token.balanceOf(users[0]), 200 * decimals);
    }

    function testInflation() public {
        uint before = token.balanceOf(address(sphere)) / 10 ** 18;

        skip(30 * 24 * 60 * 60);

        sphere.inflate();
       
        uint newInflation = (token.balanceOf(address(sphere)) / 10 ** 18) - before;

        assertEq(sphere.newInflation() / 10 ** 18, newInflation);

        assertEq(newInflation, 10604);
    }
}
