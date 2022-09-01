//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./Sphere/Sphere.sol";
import "./Sphere/EngagementToken.sol";
import "./VALU.sol";
import 'Monarchy/';

/// @notice Creates Spheres
contract SphereFactory is Monarchy {

    constructor() Monarchy(msg.sender){}

    /// @notice server_id to Sphere
    mapping(uint => address) spheres;

    /// @notice Creates server-level engagement protocol a.k.a. Spheres
    function create(
        uint, 
        EngagementToken _token, 
        VALU valu
    ) public ruled returns(address _sphere) {
        // Create Engagement Sphere
        _sphere = address(new Sphere(_token, valu, king));

        
        // Assign Engagement Sphere Profile to Server ID
        //spheres[server_id] = address(_sphere);
    }

    /// @notice Public view function for spheres mapping 
    function viewSphere(uint server_id) public view returns (address _sphere) {
        _sphere = spheres[server_id];
    }

}