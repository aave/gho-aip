// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {Helpers} from './Helpers.sol';
import './Constants.sol';

contract DeployFacilitatorAave is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

    vm.startBroadcast(deployerPrivateKey);

    Helpers.deployAaveFacilitator(address(AaveV3Ethereum.POOL), VARIABLE_BORROW_RATE);

    vm.stopBroadcast();
  }
}
