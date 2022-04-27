// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import './ERC20.sol';

//APPLEToken is the reward token for MasterChef.
contract APPLEToken is ERC20('Apple Token', 'APPLE') {
//Mints '_amount' of AppleToken to '_to'. This function can only be called by owner (Masterchef).
 function mint(address _to, uint256 _amount) public onlyOwner {
 _mint(_to, _amount);
 }
}
