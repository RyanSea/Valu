//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./Sphere/EngagementToken.sol";
import  "./VALU.sol";

import "./Interfaces/ISphere.sol";
import "./Interfaces/ISphereFactory.sol";

import "Monarchy/";

/// @title ValuDAO
contract ValuDAO is Monarchy {

    /*///////////////////////////////////////////////////////////////
                                CONSTRUCT
    //////////////////////////////////////////////////////////////*/

    ISphereFactory public immutable factory;

    VALU public immutable valu;

    constructor (ISphereFactory _factory, VALU _valu) Monarchy(msg.sender) {
        valu = _valu;

        factory = _factory;

        symbols[valu.symbol()] = true;
    }

    /*///////////////////////////////////////////////////////////////
                                CREATE
    //////////////////////////////////////////////////////////////*/

    event SphereCreated(
        uint indexed serverID,
        address indexed token, 
        address indexed _sphere,
        string token_symbol
    );

    /// @notice creates community level protocol
    function create(
        uint server_id, 
        string calldata token_name, 
        string calldata token_symbol
    ) public ruled {
        require(bytes(spheres[server_id].symbol).length == 0, "SPHERE_ALREADY_CREATED");

        require(symbols[token_symbol] == false, "SYMBOL_TAKED");
        
        EngagementToken _token = new EngagementToken(token_name, token_symbol);

        address _sphere = factory.create(server_id, _token, valu);

        //_token.annoint(_sphere);

        Sphere_Profile memory profile;

        profile.token = _token;
        profile.sphere = ISphere(_sphere);
        profile.symbol = token_symbol;

        spheres[server_id] = profile;

        valu.mint(_sphere, 10000 * 10 ** 18);

        symbols[token_name] = true;

        emit SphereCreated(server_id, address(_token), address(_sphere), token_symbol);
    }

    /*///////////////////////////////////////////////////////////////
                                CONTROL
    //////////////////////////////////////////////////////////////*/

    function authenticate(
        uint server_id,
        uint discord_id,
        address _address
    ) public ruled {
        spheres[server_id].sphere.authenticate(discord_id, _address);
    }

    function powerUp(
        uint server_id,
        uint discord_id,
        uint amount
    ) public ruled {
        spheres[server_id].sphere.powerUp(discord_id, amount);
    }

    function powerDown(
        uint server_id,
        uint discord_id,
        uint amount
    ) public ruled {
        spheres[server_id].sphere.powerDown(discord_id, amount);
    }

    function exit(
         uint server_id,
        uint discord_id,
        uint amount
    ) public ruled {
        spheres[server_id].sphere.exit(discord_id, amount);
    }

    function engage(
        uint server_id,
        uint engager_id,
        uint engagee_id
    ) public ruled {
        spheres[server_id].sphere.engage(engager_id, engagee_id);
    }  

    /*///////////////////////////////////////////////////////////////
                                REFLECT                     
    //////////////////////////////////////////////////////////////*/

    //// INTERNAL ////

    /// @notice symbol => whether or not it's in use
    mapping (string => bool) public symbols;

    /// @notice server id => Sphere Profile
    mapping(uint => Sphere_Profile) public spheres;

    struct Sphere_Profile {
        // Engagement Token Symbol
        string symbol;
        // Engagement Token
        EngagementToken token;
        // Engagement Sphere / Staked Engagement Token
        ISphere sphere;
        // Multi-sig 
        address council; // Unused      
    }
    //// EXTERNAL ////

    /// @notice get user's address by discord id
    function getAddress(uint server_id, uint discord_id) public view returns (address _address) {
        _address = spheres[server_id].sphere.getAddress(discord_id);
    }

}