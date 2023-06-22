// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/console2.sol';
import {Script} from 'forge-std/Script.sol';

import {GhoInterestRateStrategy} from 'gho-core/facilitators/aave/interestStrategy/GhoInterestRateStrategy.sol';
import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import './Constants.sol';

contract DeployGhoInterestRateStrategy is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

    vm.startBroadcast(deployerPrivateKey);

    GhoInterestRateStrategy ghoInterestRateStrategy = new GhoInterestRateStrategy(
      address(IPool(address(AaveV3Ethereum.POOL)).ADDRESSES_PROVIDER()),
      VARIABLE_BORROW_RATE
    );

    vm.stopBroadcast();
    console2.log('GhoInterestRateStrategy:', address(ghoInterestRateStrategy));
  }
}
