// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "../Sphere/EngagementToken.sol";
import "../VALU.sol";

interface ISphereFactory {
    function create(
        uint server_id, 
        EngagementToken _token, 
        VALU valu
    ) external;

    function viewSphere(uint server_id) external view returns (address);
}
