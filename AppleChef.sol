// SPDX-License-Identifier: GPL-3.0-or-later Or MIT

pragma solidity 0.6.12;
 
 
import './SafeMath.sol';
import './IERC20.sol';
import './SafeERC20.sol'; 
import './AppleToken.sol';
import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/solc-0.6/contracts/access/Ownable.sol';

/*
This MasterChef was forked from PancakeSwap and is written to use in test projects.
USE AT YOUR OWN RISK!!!!!

MasterChef is the master of Apples. He can make Apples and he is a fair guy.
This contract is ownable and this version has no governece and hence no plan to relinquish that ownership power.
The owner holds tremendous power.
*/

contract AppleMasterChef is Ownable {
 using SafeMath for uint256;
 using SafeERC20 for IERC20;

/*
Info for each user. 

The exludedReward is calculated as follows whenever a user deposits or withdraws LP tokens.
1. Pool's accApplePerShare and lastRewardBlock are updated.
2. User recieves pending award sent to their address. Always recieves total amount pending because rewardRate for new total may differ.
3. User's amount is updated. (Increases if depositing and decreases if withdrawing.)
4. User's excludedReward is updated. (Namely it excludes all rewards obtained until block after the deposit or withdrawl.)
*/

 struct UserInfo {
 uint256 amount; // # LP tokens user has depositied in contract.
 uint256 excludedReward; // Amount of the total appleRewards that user is not entitled to. (Entered contract after those rewards)
 }

 
 /*
 Info for each pool
 */
 struct PoolInfo {
 IERC20 lpToken; // Address of LP token contract.
 uint256 allocPoint; // How many allocation points assigned to this pool. Used to determine percent Apples to send per block
 uint256 lastRewardBlock; // Last block number of Apple distribution.
 uint256 accApplePerShare; // Total Accumulated Apples per share in pool, times 1e12. See below.
 uint16 depositFeeBP; // Deposit fee in basis points
 }

AppleToken public apple; // The Apple TOKEN!

 address public devaddr; // Dev address.
 address public feeAddress; // Deposit Fee address

 uint256 public applePerBlock; // Apples tokens created per block.
 uint256 public constant BONUS_MULTIPLIER = 1; // Bonus muliplier for early apple makers.


 PoolInfo[] public poolInfo; // Info of each pool.

 // Info of each user that stakes LP tokens. userInfo[which LP][which user]
 mapping (uint256 => mapping (address => UserInfo)) public userInfo;

 uint256 public totalAllocPoint = 0; // Total allocation points. Must be the sum of all allocation points in all pools.
 uint256 public startBlock; // The block number when apple mining starts.

 event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
 event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
 event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

 constructor(
 AppleToken _apple,
 address _devaddr,
 address _feeAddress,
 uint256 _applePerBlock,
 uint256 _startBlock
 ) public {
 apple = _apple;
 devaddr = _devaddr;
 feeAddress = _feeAddress;
 applePerBlock = _applePerBlock;
 startBlock = _startBlock;
 }

/*
 Gives the total number of pools in staking contract.
*/
 function poolLength() external view returns (uint256) {
 return poolInfo.length;
 }


/*
 Adds a new lp to the pool. Can only be called by the owner.
 XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do. 

 Inputs _allocPoint is value so percentage rewards you want for pool = _allocPoint/totalAllocPoint.
 _lpToken is lpToken you want new LP pool for.
 _depositFeeBP is the deposit fee you want to charge each time in basis points.
 _withUpdate is a bool. Choose 1 if you want to massUpdate all pools and 0 if you dont want to update pools.
*/
 function add(uint256 _allocPoint, IERC20 _lpToken, uint16 _depositFeeBP, bool _withUpdate) public onlyOwner {
 require(_depositFeeBP <= 10000, "add: invalid deposit fee basis points");
 if (_withUpdate) {
 massUpdatePools();
 }
 uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
 totalAllocPoint = totalAllocPoint.add(_allocPoint);
 poolInfo.push(PoolInfo({
 lpToken: _lpToken,
 allocPoint: _allocPoint,
 lastRewardBlock: lastRewardBlock,
 accApplePerShare: 0,
 depositFeeBP: _depositFeeBP
 }));
 }


/*
Updates the given pool's apple allocation point and deposit fee. Can only be called by the owner.
Inputs: _pid is pool you want to update.
_allocPoint is new allocation points want pool to have.
_depositFeeBP is new deposit fee in basis points.
_withUpdate is a bool. Choose 1 if want to massUpdatePools and 0 if not.
*/
 
 function set(uint256 _pid, uint256 _allocPoint, uint16 _depositFeeBP, bool _withUpdate) public onlyOwner {
 require(_depositFeeBP <= 10000, "set: invalid deposit fee basis points");
 if (_withUpdate) {
 massUpdatePools();
 }
 totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
 poolInfo[_pid].allocPoint = _allocPoint;
 poolInfo[_pid].depositFeeBP = _depositFeeBP;
 }

/*
 Returns the reward multiplier over the given _from to _to block.
*/
 function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
 return _to.sub(_from).mul(BONUS_MULTIPLIER);
 }

/*
 Function that calculates pending apples for _user from rewards from staking _pid.
*/
 function pendingApple(uint256 _pid, address _user) external view returns (uint256) {
 PoolInfo storage pool = poolInfo[_pid];
 UserInfo storage user = userInfo[_pid][_user];
 uint256 accApplePerShare = pool.accApplePerShare;
 uint256 lpSupply = pool.lpToken.balanceOf(address(this));
 if (block.number > pool.lastRewardBlock && lpSupply != 0) {
 uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
 uint256 appleReward = multiplier.mul(applePerBlock).mul(pool.allocPoint).div(totalAllocPoint);
 accApplePerShare = accApplePerShare.add(appleReward.mul(1e12).div(lpSupply));
 }
 return user.amount.mul(accApplePerShare).div(1e12).sub(user.excludedReward);
 }

/*
 Updates reward variables for all pools. Be careful of gas spending!
*/
 function massUpdatePools() public {
 uint256 length = poolInfo.length;
 for (uint256 pid = 0; pid < length; ++pid) {
 updatePool(pid);
 }
 }

 /*
 Updates reward variables of _pid to be up-to-date.
 */
 function updatePool(uint256 _pid) public {
 PoolInfo storage pool = poolInfo[_pid];
 if (block.number <= pool.lastRewardBlock) {
 return;
 }
 uint256 lpSupply = pool.lpToken.balanceOf(address(this));
 if (lpSupply == 0 || pool.allocPoint == 0) {
 pool.lastRewardBlock = block.number;
 return;
 }
 uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
 uint256 appleReward = multiplier.mul(applePerBlock).mul(pool.allocPoint).div(totalAllocPoint);
 //apple.mint(devaddr, appleReward.div(10)); If you want to pay a devFee, can uncomment this.
 apple.mint(address(this), appleReward);
 pool.accApplePerShare = pool.accApplePerShare.add(appleReward.mul(1e12).div(lpSupply));
 pool.lastRewardBlock = block.number;
 }

/*
 Deposits LP tokens to MasterChef to earn apples.
 When a user deposits, first pool is updated and all pendingRewards are transferred. 
 This is because if there is already some amount deposited, the new total amount will have a different reward rate.
 So you must pay out the pending rewards which then changes excludedRewards to exclude all rewards until next block.
*/

 function deposit(uint256 _pid, uint256 _amount) public {
 PoolInfo storage pool = poolInfo[_pid];
 UserInfo storage user = userInfo[_pid][msg.sender];
 require(pool.lpToken.balanceOf(msg.sender) >= _amount, "not enough lp tokens");
 updatePool(_pid);
 if (user.amount > 0) {
 uint256 pending = user.amount.mul(pool.accApplePerShare).div(1e12).sub(user.excludedReward);
 if(pending > 0) {
 safeAppleTransfer(msg.sender, pending);
 }
 }
 if(_amount > 0) {
 pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
 if(pool.depositFeeBP > 0){
 uint256 depositFee = _amount.mul(pool.depositFeeBP).div(10000);
 pool.lpToken.safeTransfer(feeAddress, depositFee);
 user.amount = user.amount.add(_amount).sub(depositFee);
 }else{
 user.amount = user.amount.add(_amount);
 }
 }
 //at time of deposit, record accApplePerShare so can be subtracted away from rewards later
 user.excludedReward = user.amount.mul(pool.accApplePerShare).div(1e12);
 emit Deposit(msg.sender, _pid, _amount);
 }

/*
 Withdraws msg.sender's LP tokens from MasterChef and also transfers all pendingRewards to msg.sender.
*/

 function withdraw(uint256 _pid, uint256 _amount) public {
 PoolInfo storage pool = poolInfo[_pid];
 UserInfo storage user = userInfo[_pid][msg.sender];
 require(user.amount >= _amount, "withdraw: withdrawal amount cannot exceed user pool balance");
 updatePool(_pid);
 uint256 pending = user.amount.mul(pool.accApplePerShare).div(1e12).sub(user.excludedReward);
 if(pending > 0) {
 safeAppleTransfer(msg.sender, pending);
 }
 if(_amount > 0) {
 user.amount = user.amount.sub(_amount);
 pool.lpToken.safeTransfer(address(msg.sender), _amount);
 }
 user.excludedReward= user.amount.mul(pool.accApplePerShare).div(1e12);
 emit Withdraw(msg.sender, _pid, _amount);
 }

/*
 Withdraws msg.senders lp tokens without caring about rewards. EMERGENCY ONLY.
*/

 function emergencyWithdraw(uint256 _pid) public {
 PoolInfo storage pool = poolInfo[_pid];
 UserInfo storage user = userInfo[_pid][msg.sender];
 uint256 amount = user.amount;
 user.amount = 0;
 user.excludedReward = 0;
 pool.lpToken.safeTransfer(address(msg.sender), amount);
 emit EmergencyWithdraw(msg.sender, _pid, amount);
 }

/*
 Safe apple transfer function, just in case if rounding error causes pool to not have enough apples.
*/

 function safeAppleTransfer(address _to, uint256 _amount) internal {
 uint256 appleBal = apple.balanceOf(address(this));
 if (_amount > appleBal) {
 apple.transfer(_to, appleBal);
 } else {
 apple.transfer(_to, _amount);
 }
 }

/*
 Updates dev address by the previous dev.
*/

 function dev(address _devaddr) public {
 require(msg.sender == devaddr, "dev: wut?");
 devaddr = _devaddr;
 }

 function setFeeAddress(address _feeAddress) public{
 require(msg.sender == feeAddress, "setFeeAddress: FORBIDDEN");
 feeAddress = _feeAddress;
 }

/*
 Updates Emmission Rate
*/

 function updateEmissionRate(uint256 _applePerBlock) public onlyOwner {
 massUpdatePools();
 applePerBlock = _applePerBlock;
 }
}
