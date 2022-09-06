// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./Utils.sol";
import "forge-std/console2.sol";

import "src/SphereFactory.sol";
import "src/VALU.sol";
import "src/ValuDAO.sol";

import "src/Interfaces/ISphereFactory.sol";



import "src/Sphere/EngagementToken.sol";

import "solmate/tokens/ERC20.sol";

contract ValuDAOTest is Test {
    VALU $valu;
    ValuDAO valudao;
    SphereFactory spherefactory;

    Utils internal utils;
    address payable[] internal users;

    ISphere sphere;

    EngagementToken token;

    address ryan;

    address alice;

    address devon;

    function setUp() public {
        utils = new Utils();
        users = utils.createUsers(3);

        vm.label(users[0], "Ryan");

        ryan = users[0];

        alice = users[1];

        devon = users[2];

        $valu = new VALU();

        spherefactory = new SphereFactory();

        valudao = new ValuDAO(ISphereFactory(address(spherefactory)), $valu);

        spherefactory.annoint(address(valudao));

        $valu.annoint(address(valudao));

        vm.label(address(valudao), "Valu");
    }

    function testSphereCreate() public {
        valudao.create(1, "Cereal Token", "YUM");

        (, token ,sphere,) = valudao.spheres(1);
        
        assertEq(token.name(), "Cereal Token");
        assertEq(token.symbol(), "YUM");
        assertTrue(address(sphere) != address(0));
    }

    function testAuth() public {
        testSphereCreate();

        valudao.authenticate(1, 123, ryan);

        assertEq(token.balanceOf(ryan), 500 ether);
    }

    function testUnstake() public {
        testStake();

        valudao.powerDown(1, 123, 500 ether);

        assertEq(sphere.balanceOf(ryan), 0);
        assertEq(token.balanceOf(ryan), 500 ether);
    }

    function testStake() public {
        testAuth();

        valudao.powerUp(1, 123, 500 ether);

        assertEq(sphere.balanceOf(ryan), 500 ether);
        assertEq(token.balanceOf(ryan), 0 ether);
    }

    function testEngage() public {
        testStake();

        valudao.authenticate(1, 321, alice);

        valudao.powerUp(1, 321, 500 ether);

        // mana is calculated with block.timestamp which is at 1 in default Anvil
        skip(10 hours);

        valudao.engage(1, 123, 321);

        valudao.engage(1,321,123);

        skip(5 hours);

        valudao.engage(1,321,123);

        skip(10 days);

        valudao.engage(1,321,123);

        skip(10 days);

        valudao.engage(1,321,123);

        skip(10 days);

        valudao.authenticate(1, 125, devon);

        valudao.engage(1,125,123);

        valudao.engage(1,123,125);

        valudao.engage(1,123,125);

        skip(356 days);

        valudao.engage(1,123,125);

        assertTrue(sphere.balanceOf(ryan) > 500 ether);

        assertTrue(sphere.balanceOf(alice) > 500 ether);

        // valudao.powerDown(1, 123, sphere.balanceOf(ryan));

        // uint ryanBal = sphere.balanceOf(ryan);

        // uint devonBal = sphere.balanceOf(devon);

        // assertTrue(sphere.balanceOf(ryan) == 0);

        // valudao.engage(1,123,125);

        // assertTrue(sphere.balanceOf(ryan) == 0);

        // assertTrue(sphere.balanceOf(devon) == devonBal);
    }

}