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
        
        // temp Set initial reward pool
        rewardPool = 100000 ether;

        last = block.timestamp;

        _mint(address(this),rewardPool);
        token.mint(address(this), rewardPool);
    }

    /*///////////////////////////////////////////////////////////////
                                  USER
    //////////////////////////////////////////////////////////////*/

    struct Profile {
        // user's eoa
        address eoa;
        // user's current Engagement Mana
        uint mana; 
        // timestamp of user's last engagement
        uint lastEngagement;
    }

    /// @notice discord id => Profile
    mapping (uint => Profile) public user;

    /// @notice address => discord id
    /// @dev for direct eoa staking / unstaking
    mapping (address => uint) public discord;

    /// @notice server id => server owner id (discord)
    mapping (uint => uint) public server_owner;

    /*///////////////////////////////////////////////////////////////
                                  LOGIN
    //////////////////////////////////////////////////////////////*/

    /// @notice user authenticated with eoa
    event Authenticate(uint indexed discord_id, address indexed _address);

    /// @notice owner id assigned to server id (discord)
    event OwnerAssigned(uint indexed server_id, uint indexed owner_id);

    /// @notice maps user wallet to Profile
    function authenticate(uint discord_id, address _address) public ruled  {
        // create Profile struct 
        Profile memory profile;

        // set address for struct
        profile.eoa = _address;

        // assign profile to discord id
        user[discord_id] = profile;

        // assign discord id to address
        discord[_address] = discord_id;

        // temp mint 500 tokens for newly authed user
        token.mint(_address, 500 * 10 ** 18);

        emit Authenticate(discord_id, _address);
    }

    /// @notice returns user eoa from discord address
    function getAddress(uint discord_id) public view returns (address _address) {
        _address = user[discord_id].eoa;
    }

    /*///////////////////////////////////////////////////////////////
                                 STAKE
    //////////////////////////////////////////////////////////////*/
    
    /// @notice staking event
    /// @param _internal Called from ValuBot vs called from user eoa
    event PowerUp(
        uint indexed discord_id, 
        address indexed _address,
        uint amount,
        bool indexed _internal
    );

    /// @notice unstaking event
    event PowerDown(
        uint indexed discord_id,
        address indexed _address,
        uint amount,
        bool indexed _internal
    );
    
    /// @notice event for exchchanging staked tokens for VALU
    event Exit(
        uint indexed discord_id,
        address indexed _address,
        uint amountBurnt,
        uint amountValu,
        bool indexed _internal 
    );

    /// @notice stake
    function powerUp(uint discord_id, uint amount) public ruled returns(bool success) {
        address _address = user[discord_id].eoa;

        uint _balance = token.balanceOf(_address);

        uint _amount = _balance >= amount ? amount : _balance;

        token.allow(_address, _amount);

        success = token.transferFrom(_address, address(this), _amount);

        _mint(_address, _amount);

        emit PowerUp(discord_id, _address, _amount, true);
    }

    /// @notice unstake
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
    
    /// @notice rate of interest
    /// @notice 0.00000003 * scalar | about 8% MoM
    uint public rate = .00000003 ether;

    /// @notice new tokens from last inflation
    uint public inflation;

    /// @notice multiple to get rate to whole num
    uint public scalar = 1e18;

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
        
        uint onePlusR = 1 ether + rate;

        // compound interest forumula: P(1 + r/n) ** nt
        // implemented: rewardPool(1 + .00000003) ** intervals
        // note didn't need to include n since n = 1
        inflation = rewardPool * onePlusR.rpow(intervals, scalar) / scalar;

        // mint new inflation
        token.mint(address(this), inflation);

        // add to reward pool
        rewardPool += inflation;
        
        // update last to current timestamp
        last = current;

        emit Inflation(last, inflation); 
    }

    /// @notice engagement mana dictates user engagement power | 0 - 100
    /// @notice decreases by 10% with each use and increases by 1 every 36 seconds
    function calculateMana(uint discord_id) private {
        // Add 1 mana for every 36 seconds that past since last engagement
        uint mana = user[discord_id].mana + (block.timestamp - user[discord_id].lastEngagement) / 36;

        // Cap mana at 100
        user[discord_id].mana = mana > 100 ? 100 : mana;
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

        engager.lastEngagement = block.timestamp;
       
        uint _mana = engager.mana;

        // decrease mana by 10%
        engager.mana = _mana - (_mana * 10 / 100);

        // save updated Profile to storage
        user[engager_id] = engager;

        uint staked = balanceOf[engager.eoa];

        // return if user has no stake
        if (staked == 0) return;

        // calculate Engagement Value
        // temp still figuring out exactly how I'm going to do this
        /* 
        *  in general, rewards (both inflation and especially this 'engagement value' equation) are somthing
        *  that I need to spend more time thinking about. the reward pool should never be empty and the 
        *  end result will likely look similar to a constant function market maker — the lower the reward pool
        *  relative to total staked, the less a single staked token can earn on engagement. 
        *
        *  for now this equation works like this: pool = 100, user_stake = 25, value = 25
        *  then it uses a percentage of that based on the user's mana
        */
        uint value = rewardPool / (rewardPool / staked) * engager.mana / 100;

        // mint Powered Engagement Tokens and distribute to engagee (80%) + engager (20%)
        _mint(engager.eoa, value * 20 / 100); 
        _mint(user[engagee_id].eoa, value * 80 / 100);

        // remove engagement value from reward pool
        rewardPool -= value;

        emit Engagement(engager_id, engagee_id, block.timestamp, value);
    }

    /*///////////////////////////////////////////////////////////////
                            USER EOA STAKING
    //////////////////////////////////////////////////////////////*/

    /// @notice powerup From eoa
    function stake(uint amount) public {
        uint _balance = token.balanceOf(msg.sender);

        uint _amount = _balance >= amount ? amount : _balance;


        token.transferFrom(msg.sender, address(this), _amount);

        _mint(msg.sender, _amount);

        emit PowerUp(discord[msg.sender], msg.sender, _amount, false);
    }

    /// @notice powerdown from eoa
    function unstake(uint amount) public {
        uint _balance = balanceOf[msg.sender];

        uint _amount = _balance >= amount ? amount : _balance;

        _burn(msg.sender, _amount);

        token.transfer(msg.sender, _amount);

        emit PowerDown(discord[msg.sender], msg.sender, _amount, false);
    }
    
    /// @notice exit from eoa
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