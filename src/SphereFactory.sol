//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./Sphere/Sphere.sol";
import "./Sphere/EngagementToken.sol";
import "./VALU.sol";

contract SphereFactory {

    /// @notice server_id to Sphere
    mapping(uint => address) spheres;

    /// @notice Creates community level protocol
    /// TODO Add Gnosis multisig functionality for spheres
    function create(uint server_id, EngagementToken _token, VALU valu) public {
        // Create Engagement Sphere
        Sphere _sphere = new Sphere(_token, valu);

        // Assign Engagement Sphere Profile to Server ID
        spheres[server_id] = address(_sphere);
    }

    function viewSphere(uint server_id) public view returns (address _sphere) {
        _sphere = spheres[server_id];
    }

}