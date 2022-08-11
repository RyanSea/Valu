// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./Utils.sol";
import "forge-std/console2.sol";

import "src/SphereFactory.sol";
import "src/VALU.sol";
import "src/ValuDAO.sol";

import "src/Interfaces/ISphereFactory.sol";

contract ValuDAOTest is Test {
    VALU $valu;
    ValuDAO valudao;
    SphereFactory spherefactory;

    Utils internal utils;
    address payable[] internal users;

    function setUp() public {
        utils = new Utils();
        users = utils.createUsers(1);

        vm.label(users[0], "Ryan");

        $valu = new VALU();

        spherefactory = new SphereFactory();

        valudao = new ValuDAO(ISphereFactory(address(spherefactory)), $valu);

        spherefactory.annoint(address(valudao));

        vm.label(address(valudao), "Valu");
    }

    function testSphereCreate() public {
        console.log("DAO Address:",address(valudao));
        console.log("This Wallet:",msg.sender);
        console.log("SphereFactory",address(spherefactory));

        valudao.create(1, "Cereal Token", "YUM");
    }

}