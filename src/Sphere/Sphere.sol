// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "solmate/tokens/ERC20.sol";
import "./EngagementToken.sol";
import "../VALU.sol";
import "Monarchy";

import "forge-std/console2.sol";

/// TODO Modify monarchy to not need a constructor?
/// @title Engagement Sphere
/// @notice Engagement Protocol that rewards engagement-tokens based on
/// the staked engagement-tokens of the person making the engagement.
/// Non-transferable 🤍TOKEN is the staked TOKEN. 
contract Sphere is ERC20, Monarchy {
    /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/  

    EngagementToken immutable public token;
    VALU immutable public valu;

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

    /// FROM APP ///

    /// @notice Stake
    function powerUp(uint discord_id, uint amount) public ruled returns(bool success) {
        console.log("ADDRESS:", msg.sender);

        address _address = user[discord_id].eoa;

        uint _balance = token.balanceOf(_address);

        uint _amount = _balance >= amount ? amount : _balance;

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

    /// FROM EOA ///

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
                        CORE ENGAGEMENT PROTOCOL
    //////////////////////////////////////////////////////////////*/

    /// @notice Reward pool that fills with inflation and gets distrubuted as yield 
    uint public rewardPool;

    /// @notice Last time inflation was calculated 
    uint public last; 

    /// @notice Compound frequency in seconds 
    uint public frequency = 30;

    /// @notice Rate of inflation (x 10000000000) | 0.0000011666 | 10.6% /month @ 30 sec freq
    uint public inflation = 11666;

    /// @notice Number of tokens from last inflationary event
    uint public newInflation;

    /// @notice The multiple required to get infllation to a whole number
    uint public multiple = 10000000000;

    /// @notice Engagement-Action between users
    event Engagement(
        uint indexed from_discord_id,
        uint indexed to_discord_id,
        uint indexed time,
        uint value
    );

    /// @notice Inflation event
    event Inflation(uint time, uint amount);

    /// @notice Inflate the rewardPool based on the amount of Powered Up Engagement Tokens
    function inflate() public {
        // Caulculate inflation intervals since last inflation event
        uint current = block.timestamp;

        uint intervals = (current - last) /  frequency;

        if (intervals == 0) return;
        
        newInflation = totalSupply;

        // Calculate new inflation
        // TODO Optimize this
        for(uint i; i < intervals; ++i){
            newInflation += newInflation * inflation / multiple;
        }
        newInflation -= totalSupply;

        // Mint new inflation
        token.mint(address(this), newInflation);

        // Add to reward pool
        rewardPool += newInflation;
        
        // Update last to current timestamp
        last = current;

        emit Inflation(last, newInflation); 
    }

    /// @notice Engagement Mana dictates user engagement power. It can be 1-100 
    /// it decreases by 10 with use and increases by 1 every 36 seconds
    function calculateMana(uint discord_id) private {
        // Add 1 mana for every 36 seconds that past since last engagement
        uint mana = user[discord_id].mana + (block.timestamp - user[discord_id].lastEngagement) / 36;

        // Cap mana at 100
        user[discord_id].mana = mana <= 100 ? mana : 100;
    }

    /// @notice Core engagement function
    /// TODO Reward server from engagement 
    function engage(
        // All params are discord id's
        uint engager_id, 
        uint engagee_id
    ) public ruled {
        // Mint Engagement Tokens to reward pool
        inflate();

        // Caluclate Engager's current Engagement Mana
        calculateMana(engager_id);

        // Assign engager to variable
        Profile storage engager = user[engager_id];

        // Calculate Engagement Value
        uint value = rewardPool / balanceOf[engager.eoa] / 100 * engager.mana;

        // Decimals
        value *= 10 ** 18;

        // Mint Powered Engagement Tokens and distribute to engagee (80%) + engager (20%)
        // The Engagement Tokens minted upon inflate() are now withdrawable
        _mint(engager.eoa, value * 20 / 100); 
        _mint(user[engagee_id].eoa, value * 80 / 100);

        // Remove engagement value from reward pool
        rewardPool -= value;

        // Update engager's profile
        engager.lastEngagement = block.timestamp;

        // Remove 10 Engagement Mana from engager
        engager.mana -= 10;

        emit Engagement(engager_id, engagee_id, block.timestamp, value);
    }

    /*///////////////////////////////////////////////////////////////
                                OVERRIDES
    //////////////////////////////////////////////////////////////*/
    /// @notice Override transfer functions to make token non-transferable

    function transfer(address to, uint256 amount) public virtual override returns(bool) {
        to;
        amount;
        return false; 
    }

    function transferFrom(
        address from, 
        address to, 
        uint256 amount
    ) public virtual override returns(bool) {
        from;
        to;
        amount;
        return false;
    }

}