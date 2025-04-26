// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract SolarVault is ERC4626, Ownable, AccessControl {
    
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant TRANSACTION_ROLE = keccak256("TRANSACTION_ROLE");

    uint256 public fee;  //5% is 500bps
    uint256 public lockPeriod; // days
    uint256 public penalty; // 5% is 500bps

    mapping(address => uint256) public depositTimestamps;

    constructor(IERC20 _asset, uint256 _fee, uint256 _lockPeriod, uint256 _penalty, address _owner )
        ERC20("Solar Vault Share", "SVS")
        ERC4626(_asset)
        Ownable(_owner)
    {
        fee = _fee;
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        lockPeriod = _lockPeriod * 1 days;
        penalty = _penalty;
    }

    
    function deposit(uint256 assets, address receiver) public override returns (uint256) {
        uint256 shares = super.deposit(assets, receiver);
        if (depositTimestamps[receiver] == 0) {
            depositTimestamps[receiver] = block.timestamp;
        }
        return shares;
    }

    
    function mint(uint256 shares, address receiver) public override returns (uint256) {
        uint256 assets = super.mint(shares, receiver);
        if (depositTimestamps[receiver] == 0) {
            depositTimestamps[receiver] = block.timestamp;
        }
        return assets;
    }

    // Restricted function to inject subscription revenue as yield
    function addYield(uint256 amount) public returns (bool) {
        require(amount > 0, "Amount must be greater than zero");
        require( hasRole(MANAGER_ROLE, msg.sender) || hasRole(TRANSACTION_ROLE, msg.sender), "Not authorized!");
        IERC20(asset()).transferFrom(msg.sender, address(this), amount);
        return true;
    }

    
    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256) {
       assets;
        receiver;
        owner;
        revert("Withdraw function is not allowed in this vault.");
    }

    
    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256) {
        require(block.timestamp >= depositTimestamps[owner] + lockPeriod, "Lock period not over");
        
        uint256 assets = super.redeem(shares, address(this), owner);
        bool earlyRedeem = _canRedeemFullAmount(receiver);
       
        if (!earlyRedeem && shares > 0 ) {
         IERC20(asset()).transfer(receiver, assets); //full payout.
        }else {
            uint256 _penalty = (assets * penalty) / 10000;
            uint256 penalized = assets - _penalty;

            IERC20(asset()).transfer(receiver, penalized);
            IERC20(asset()).transfer(owner, _penalty);
        }
        return assets;
    }


    /////// MANAGMENT LOGIC ////////
    ///////////////////////////////

    // Helper to check if user can redeem
    function _canRedeemFullAmount(address user) public view returns (bool) {
        return block.timestamp >= depositTimestamps[user] + lockPeriod;
    }

    // Admin function to adjust lock period if needed
    function setLockPeriod(uint256 _newLockPeriod) external onlyOwner {
        lockPeriod = _newLockPeriod;
    }


}
