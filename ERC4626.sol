// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC20} from 'https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC20.sol';
import {SafeTransferLib} from 'https://github.com/Rari-Capital/solmate/blob/main/src/utils/SafeTransferLib.sol';
import {FixedPointMathLib} from 'https://github.com/Rari-Capital/solmate/blob/main/src/utils/FixedPointMathLib.sol';

/// @notice Minimal ERC4626 tokenized Vault implementation.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/mixins/ERC4626.sol)

/*
Note that the tokens of this contract are the shares.
*/

abstract contract ERC4626 is ERC20 {
    //Library for ERC20 Token
    using SafeTransferLib for ERC20;
    //Decimals -- Boilerplate
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    //Records
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);

    //Records
    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /*
    Token that you want to deposit as an asset.
    */

    ERC20 public immutable asset;

    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol, _asset.decimals()) {
        asset = _asset;
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /* 
    Input # of assets and who you want to recieve the shares.

    Sets shares=previewDeposit(assets). As previewDeposit rounds down, must have a require statment to avoid 
    rounding error that would give 0 shares for small amount of assets.

    It thentransfers # assets given in function input assets from message sender to this address.
    
    Next it mints shares to the reciever.

    Then emits deposit for the front end.

    Finally custom code for after deposit.
    */

    function deposit(uint256 assets, address receiver) public virtual returns (uint256 shares) {
        // Check for rounding error since we round down in previewDeposit.
        require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        afterDeposit(assets, shares);
    }

    /*
    Input # of shares you want to recieve and who you want to recieve the shares.

    Sets assets=previewMint(shares). (This rounds up so no require statement needed.)

    Next transfers assets from message sender to this address.

    After this it mints shares to the reciever.

    Then it emits deposit for front end.

    Finally custom code for after deposit.
    */

    function mint(uint256 shares, address receiver) public virtual returns (uint256 assets) {
        assets = previewMint(shares); // No need to check for rounding error, previewMint rounds up.

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        afterDeposit(assets, shares);
    }

    /*
    Input # assets you want to have after withdrawing shares, who you want to recieve them, and then the owner
    of the shares.

    Sets shares = previewWithdraw(assets). (Rounds up so no require statement needed.)

    Then if message sender is owner it sets allowed = amount of tokens already approved to be sent from owner
    to message sender. If this allowed amount was not infinite, then it will set the new allowence to be the
    previous allowence minus the shares that are being withdrew.

    Then custom code for before withdrawal.

    After this it burns the shares of the owner.

    Then emits withdrawl for front end.

    Finally it transfers the receiver the assets.
    */

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual returns (uint256 shares) {
        shares = previewWithdraw(assets); // No need to check for rounding error, previewWithdraw rounds up.

        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        beforeWithdraw(assets, shares);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);
    }

    /*
    Input # share you want to withdraw, who you want to recieve them, and then the owner
    of the shares.

    If message sender is owner it sets allowed = amount of tokens already approved to be sent from owner
    to message sender. If this allowed amount was not infinite, then it will set the new allowence to be the
    previous allowence minus the shares that are being withdrew.

    Sets assets = previewRedeem(shares). Notice previewRedeem rounds down, so must have a require statment to avoid 
    rounding error that would give 0 assets for small amount of shares.

    Then custom code for before withdrawal.

    After this it burns the shares of the owner.

    Then emits withdrawl for front end.

    Finally it transfers the receiver the assets.
    */

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual returns (uint256 assets) {
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        // Check for rounding error since we round down in previewRedeem.
        require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");

        beforeWithdraw(assets, shares);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /* Total amount of assets magaed by protocol. Includes all assets in vault + assets in farm.
    One needs to define this in vault strategy as it needs to include the additional assets the strategy yields.
    */
    function totalAssets() public view virtual returns (uint256);

    /* Returns the amount of shares that would be exchanged for the amount of assets input.

    If totalSupply of shares is 0, returns assets.
    If totalSupply nonzero, returns assets * supply / totalAssets(rounded down).
    */
    function convertToShares(uint256 assets) public view virtual returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets());
    }

    /* Returns the amount of Assets that would be echanged for the amount of shares input.

    If totalSupply of shares is 0, returns shares.
    If totalSupply of shares is nonzero, returns shares * totalAssets / totalSupply (rounded down).
    */

    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? shares : shares.mulDivDown(totalAssets(), supply);
    }

    /* Returns amount of shares you would recieve in exchange for assets (rounded down).
    */

    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        return convertToShares(assets);
    }

    /* Returns amount of assets you would recieve in exchange for shares (rounded up).

    If totalSupply of shares is 0, returns shares.
    If totalSupply of shares is nonzero, returns shares * totalAssets / totalSupply. (rounded up)
    */

    function previewMint(uint256 shares) public view virtual returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? shares : shares.mulDivUp(totalAssets(), supply);
    }

    /* Returns amount of shares you would can recieve in exchange for assets (rounded up)

    If totalSupply of shares is 0, returns assets.
    If totalSupply of shares is nonzero, returns assets*totalSupply/totalAssets (rounded up).
    */

    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? assets : assets.mulDivUp(supply, totalAssets());
    }

    /*
    Returns amount of assets you can recieve in exchange for shares (rounded down).
    */

    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
        return convertToAssets(shares);
    }

    /*//////////////////////////////////////////////////////////////
                     DEPOSIT/WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    /*
    Shows max amount of assets that address can deposit.
    */
    function maxDeposit(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    /*
    Shows max amount of shares that address can mint.
    */
    function maxMint(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    /*
    Shows the max amount of asset address can withdraw.
    */
    function maxWithdraw(address owner) public view virtual returns (uint256) {
        return convertToAssets(balanceOf[owner]);
    }

    /*
    Shows the max amount of shares address can redeem.
    */
    function maxRedeem(address owner) public view virtual returns (uint256) {
        return balanceOf[owner];
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HOOKS LOGIC
    //////////////////////////////////////////////////////////////*/

    /*
    Custom code for deposit fees, withdrawl fees, etc...
    */

    function beforeWithdraw(uint256 assets, uint256 shares) internal virtual {}

    function afterDeposit(uint256 assets, uint256 shares) internal virtual {}
}

contract AppleVault is ERC4626 {
   // ERC20 public override asset ; 
    
    constructor(
        ERC20  _asset,
        string memory _name,
        string memory _symbol
    ) ERC4626(_asset,_name, _symbol) {
       // asset = _asset;
    }


//
// assets in vault plus in farm pool
// THIS NEEDS TO BE FIXED 
    function totalAssets() public view override returns (uint256){
        return ERC20(asset).balanceOf(address(this)); 
    }
}
