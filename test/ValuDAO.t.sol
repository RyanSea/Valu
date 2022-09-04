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

    function setUp() public {
        utils = new Utils();
        users = utils.createUsers(1);

        vm.label(users[0], "Ryan");

        ryan = users[0];

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

        assertEq(sphere.balanceOf(ryan), 500 ether);
    }

    function testUnstake() public {
        testAuth();

        valudao.powerDown(1, 123, 500 ether);

        assertEq(sphere.balanceOf(ryan), 0);
        assertEq(token.balanceOf(ryan), 500 ether);
    }

    function testStake() public {
        testUnstake();

        valudao.powerUp(1, 123, 250 ether);

        assertEq(sphere.balanceOf(ryan), 250 ether);
        assertEq(token.balanceOf(ryan), 250 ether);
    }

}