// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.0;

/* 
The following contract gives an autocompounding strategy using the EIP 4646 Tokenized Vault Standard.
In this iteration it is working with a staking contract, that pays in the same coin that is deposited.
In later iterations, I will have it work with LP pools of popular DEX's that pay in a reward token.

This iteration is designed to work as follows with AppleMasterChef. See https://github.com/Appledude101/MasterChef.
*/

import "./ERC4626.sol";
import "./SafeMath8.sol";
import "./IMasterAppleChef.sol";

contract AutoCompound4626 is ERC4626 {
    using SafeMath for uint;
    using SafeTransferLib for ERC20;

    //PID is pool ID for pair in MasterAppleChef.
    uint public PID = 0;

    IERC20 public apple;
    IMasterAppleChef public stakingContract;

    //Apple Token Address
    address public constant _apple = 0xBbB76769D71302a828D5a745B4e984ceFE345cBF;
 
    //staking in AppleMasterChef
    address public constant _stakingContract = 0x1AA5C230fFaCc818655503d39a14adE6F96d81D0;

    //Owner of Strategy Vault
    address public owner;

    event Deposit(address account, uint amount);
    event Withdraw(address account, uint amount);
    event Redeem(address account, uint amount);
    event Recovered(address token, uint amount);
    event Reinvest(uint newTotalAssets);

    constructor() ERC4626(ERC20(_apple), "Apple Token", "APPLE") public {
        owner = msg.sender;
        apple = IERC20(_apple);
        stakingContract = IMasterAppleChef(_stakingContract);
        apple.approve(_stakingContract, type(uint).max);
        
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    //As it is single staking for same reward token. Total assets is just balance of apple.
    function totalAssets() public override view returns (uint256) { 
    return stakingContract.userInfo(PID,address(this)).amount;
    }

    function deposit(uint256 amount, address receiver) public override returns (uint256 shares) {
        // Check for rounding error since we round down in previewDeposit. 
        require((shares = previewDeposit(amount)) != 0, "ZERO_SHARES");

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), amount);

        _stakeApple(amount);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, amount, shares);

        afterDeposit(amount, shares);
    }


    /*
    Function redeems shares for alloted amount of asset in protocol.
    First makes sure that assets will be non-zero as previewRedeem rounds down.
    Next calculates the pending rewards that will be harvested and if nonzero calls reinvest function.
    Must then recalculate assets as total assets will increase if reinvested as total assets only counts those assets staked.
    It then stakes the rewards that msg.Sender is not entitles too.
    Burns the shares and then finally transfers assets (including any pending rewards) to msg.Sender.
`   */

function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override returns (uint256 assets) {
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        // Check for rounding error since we round down in previewRedeem.
        require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");

        if (pendingRewardAmt() !=0 ) {reinvest();}

        assets = previewRedeem(shares);
        
        _withdrawApple(assets);

        beforeWithdraw(assets, shares);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);
    }
      

function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override returns (uint256 shares) {

        if (pendingRewardAmt() !=0 ) {reinvest();}

        shares = previewWithdraw(assets); // No need to check for rounding error, previewWithdraw rounds up.

        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        _withdrawApple(assets);

        beforeWithdraw(assets, shares);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);
    }
   
    /*
    Finds pending rewards in the staking contract for the vault. That is apples that have been earned, but not staked.
    */
    function pendingRewardAmt() public view returns (uint) {
        uint pendingReward = stakingContract.pendingApple(PID, address(this));
        return pendingReward;
    }
     

    function _stakeApple(uint amount) internal {
        require(amount > 0, "amount too low");
        //vault contract gives approval to stakingContract for deposit in constructor
        stakingContract.deposit(PID, amount);
    }

    function _withdrawApple(uint amount) internal {
        require(amount >0, "amount too low");
        stakingContract.withdraw(PID, amount);
    }

    function reinvest() internal onlyOwner {
        _withdrawApple(totalAssets());
        _stakeApple(apple.balanceOf(address(this)));
        emit Reinvest(apple.balanceOf(address(this)));
    }

    function emergencyWithdraw() external onlyOwner {
        stakingContract.emergencyWithdraw(PID);
    }

    function recoverERC20(address tokenAddress, uint tokenAmount) external onlyOwner {
        require(tokenAmount > 0, "amount too low");
        IERC20(tokenAddress).transfer(msg.sender, tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    /*
    Changed to include pending assets owner also entitled to.
    */
    function maxWithdraw(address owner) public view override returns (uint256) {
        uint maxPendingAssets = pendingRewardAmt().mul(maxRedeem(owner)).div(totalSupply);
        return convertToAssets(balanceOf[owner])+maxPendingAssets;
    }
