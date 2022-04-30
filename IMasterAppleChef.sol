// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
pragma experimental ABIEncoderV2;


interface IMasterAppleChef{
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 excludedReward; // Reward debt. See explanation below.
    }

    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. JOE to distribute per block.
        uint256 lastRewardTimestamp; // Last block number that JOE distribution occurs.
        uint256 accApplePerShare; // Accumulated JOE per share, times 1e12. See below.
        uint16 depositFeeBP; // Deposit fee in basis points
    }

    function userInfo(uint256 _pid, address _user) external view returns (IMasterAppleChef.UserInfo memory);

    function poolInfo(uint256 pid) external view returns (IMasterAppleChef.PoolInfo memory);

    function totalAllocPoint() external view returns (uint256);

    function applePerBlock() external view returns (uint256);

    function deposit(uint256 _pid, uint256 _amount) external;

    function withdraw(uint256 _pid, uint256 _amount) external;

    function emergencyWithdraw(uint _pid) external;

    function pendingApple(uint256 _pid, address _user) external view returns (uint256);

}

//ERC20 Interface
interface IERC20 {
    function totalSupply() external view returns (uint);

    function balanceOf(address account) external view returns (uint);

    function transfer(address recipient, uint amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool);
}
