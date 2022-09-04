// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "solmate/tokens/ERC20.sol";
import "solmate/utils/FixedPointMathLib.sol";

import "./EngagementToken.sol";
import "../VALU.sol";
import "Monarchy/";

import "forge-std/console.sol";

import "forge-std/console2.sol";

/// TODO Modify monarchy to not need a constructor?
/// @title Engagement Sphere
/// @notice tokenized engagement protocol
contract Sphere is ERC20, Monarchy {
    /*///////////////////////////////////////////////////////////////
                             INITIALIZATION
    //////////////////////////////////////////////////////////////*/  
    
    EngagementToken immutable public token;

    VALU immutable public valu;

    using FixedPointMathLib for uint;

    constructor(
        EngagementToken _token, 
        VALU _valu,
        address _king
    ) Monarchy(_king) ERC20(
        string(abi.encodePacked(unicode"🤍-", _token.name())),
        string(abi.encodePacked(unicode"🤍", _token.symbol())),
        18
    ) {
        token = _token;
        valu = _valu;
        
        // TEMP Set initial reward pool
        rewardPool = 100000 * 10 ** 18;

        last = block.timestamp;

        _mint(address(this),rewardPool);
        token.mint(address(this), rewardPool);
    }

    /*///////////////////////////////////////////////////////////////
                                  USER
    //////////////////////////////////////////////////////////////*/

    struct Profile {
        // User's eoa
        address eoa;
        // User's current Engagement Mana
        uint mana; 
        // Timestamp of user's last engagement
        uint lastEngagement;
    }

    /// @notice Discord id => Profile
    mapping (uint => Profile) public user;

    /// @notice Address => discord id
    /// @dev for direct eoa staking / unstaking
    mapping (address => uint) public discord;

    /// @notice Server id => server owner id (discord)
    mapping (uint => uint) public server_owner;

    /*///////////////////////////////////////////////////////////////
                                  LOGIN
    //////////////////////////////////////////////////////////////*/

    /// @notice User authenticated with Ethereum wallet
    event Authenticate(uint indexed discord_id, address indexed _address);

    /// @notice Owner id assigned to server id (discord)
    event OwnerAssigned(uint indexed server_id, uint indexed owner_id);

    /// @notice Assigns address to a user's Profile struct and maps struct to discord id
    function authenticate(uint discord_id, address _address) public ruled  {
        // Create Profile struct 
        Profile memory profile;

        // Set address for struct
        profile.eoa = _address;

        // Assign profile to discord id
        user[discord_id] = profile;

        // Assign discord id to address
        discord[_address] = discord_id;

        // TEMP Mint 500 tokens for newly authed user
        _mint(_address, 500 * 10 ** 18);

        emit Authenticate(discord_id, _address);
    }

    function getAddress(uint discord_id) public view returns (address _address) {
        _address = user[discord_id].eoa;
    }

    /*///////////////////////////////////////////////////////////////
                                 STAKE
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Staking event
    event PowerUp(
        uint indexed discord_id, 
        address indexed _address,
        uint amount,
        bool indexed _internal
    );

    /// @notice Unstaking event
    event PowerDown(
        uint indexed discord_id,
        address indexed _address,
        uint amount,
        bool indexed _internal
    );
    
    /// @notice Event for exchchanging staked tokens for VALU
    /// @param _internal Called from ValuBot
    event Exit(
        uint indexed discord_id,
        address indexed _address,
        uint amountBurnt,
        uint amountValu,
        bool indexed _internal 
    );

    /// @notice Stake
    function powerUp(uint discord_id, uint amount) public ruled returns(bool success) {
        address _address = user[discord_id].eoa;

        uint _balance = token.balanceOf(_address);

        uint _amount = _balance >= amount ? amount : _balance;

        token.allow(_address, _amount);

        success = token.transferFrom(_address, address(this), _amount);

        _mint(_address, _amount);

        emit PowerUp(discord_id, _address, _amount, true);
    }

    /// @notice Unstake
    function powerDown(uint discord_id, uint amount) public ruled {
        address _address = user[discord_id].eoa;

        uint _balance = balanceOf[_address];

        uint _amount = _balance >= amount ? amount : _balance;
        
        _burn(_address, _amount);

        token.transfer(_address, _amount);

        emit PowerDown(discord_id, _address, _amount, true);
    }

    /// @notice burn staked tokens for $VALU
    function exit(uint discord_id, uint amount) public ruled {
        address _address = user[discord_id].eoa;

        uint _balance = balanceOf[_address];

        uint _amount = _balance >= amount ? amount : _balance;

        uint _valu = valu.balanceOf(address(this)) / totalSupply * _amount;

        _burn(_address, _amount);

        token.burn(address(this), _amount);

        valu.transfer(_address, _valu);

        emit Exit(discord_id, _address, _amount, _valu, true);
    }

    /*///////////////////////////////////////////////////////////////
                        CORE ENGAGEMENT PROTOCOL
    //////////////////////////////////////////////////////////////*/

    /// @notice reward pool fills with inflation & gets distributed as yield
    uint public rewardPool;

    /// @notice last inflationary event
    uint public last; 

    /// @notice rate of inflation (x 100000000000) 
    uint public inflation = 11666;

    /// @notice new tokens from last inflation
    uint public newInflation;

    /// @notice multiple to get inflation to whole num
    uint public multiple = 100000000000;

    /// @notice engagement-Action between users
    event Engagement(
        uint indexed from_discord_id,
        uint indexed to_discord_id,
        uint indexed time,
        uint value
    );

    /// @notice inflation event
    event Inflation(uint time, uint amount);

    /// @notice inflate the rewardPool based on the amount of Powered Up Engagement Tokens
    function inflate() public {
        // Caulculate inflation intervals since last inflation event
        uint current = block.timestamp;

        uint intervals = current - last;

        if (intervals == 0) return;
        
        newInflation = totalSupply;

        // calculate new inflation
        // todo optimize this
        for(uint i; i < intervals; ++i){
            newInflation += newInflation * inflation / multiple;
        }
        newInflation -= totalSupply;

        // mint new inflation
        token.mint(address(this), newInflation);

        // add to reward pool
        rewardPool += newInflation;
        
        // update last to current timestamp
        last = current;

        emit Inflation(last, newInflation); 
    }

    /// @notice engagement mana dictates user engagement power | 0 - 100
    /// @notice decreases by 10 with each use and increases by 1 every 36 seconds
    function calculateMana(uint discord_id) private {
        // Add 1 mana for every 36 seconds that past since last engagement
        uint mana = user[discord_id].mana + (block.timestamp - user[discord_id].lastEngagement) / 36;

        // Cap mana at 100
        user[discord_id].mana = mana <= 100 ? mana : 100;
    }

    /// @notice core engagement function
    /// todo reward server from engagement (platform rewards)
    function engage(
        uint engager_id, 
        uint engagee_id
    ) public ruled {
        // mint Engagement Tokens to reward pool
        inflate();

        // caluclate engagement mana
        calculateMana(engager_id);

        // load engager's Profile to memory
        Profile memory engager = user[engager_id];

        // update engager's Profile
        engager.lastEngagement = block.timestamp;
        engager.mana -= 10;

        // save updated Profile to storage
        user[engager_id] = engager;

        // calculate Engagement Value
        uint value = rewardPool / balanceOf[engager.eoa] / 100 * engager.mana;

        // decimals
        value *= 10 ** 18;

        // mint Powered Engagement Tokens and distribute to engagee (80%) + engager (20%)
        // the Engagement Tokens minted upon inflate() are now withdrawable
        _mint(engager.eoa, value * 20 / 100); 
        _mint(user[engagee_id].eoa, value * 80 / 100);

        // remove engagement value from reward pool
        rewardPool -= value;

        emit Engagement(engager_id, engagee_id, block.timestamp, value);
    }

    /*///////////////////////////////////////////////////////////////
                            USER EOA STAKING
    //////////////////////////////////////////////////////////////*/

    /// @notice PowerUp From EOA
    function stake(uint amount) public {
        uint _balance = token.balanceOf(msg.sender);

        uint _amount = _balance >= amount ? amount : _balance;


        token.transferFrom(msg.sender, address(this), _amount);

        _mint(msg.sender, _amount);

        emit PowerUp(discord[msg.sender], msg.sender, _amount, false);
    }

    /// @notice PowerDown from EOA
    function unstake(uint amount) public {
        uint _balance = balanceOf[msg.sender];

        uint _amount = _balance >= amount ? amount : _balance;

        _burn(msg.sender, _amount);

        token.transfer(msg.sender, _amount);

        emit PowerDown(discord[msg.sender], msg.sender, _amount, false);
    }
    
    /// @notice Exit from EOA
    function claim(uint amount) public {
        uint _balance = balanceOf[msg.sender];

        uint _amount = _balance >= amount ? amount : _balance;

        uint _valu = valu.balanceOf(address(this)) / totalSupply * _amount;

        _burn(msg.sender, _amount);

        token.burn(address(this), _amount);

        valu.transfer(msg.sender, _valu);

        emit Exit(discord[msg.sender], msg.sender, _amount, _valu, false);
    }

    /*///////////////////////////////////////////////////////////////
                               SOULBOUND
    //////////////////////////////////////////////////////////////*/
    /// @notice override transfer functions to make token non-transferable

    function transfer(address, uint256) public virtual override returns (bool) {
        revert("SOULBOUND");
    }

    function transferFrom(
        address, 
        address, 
        uint256
    ) public virtual override returns (bool) {
        revert("SOULBOUND");
    }

}