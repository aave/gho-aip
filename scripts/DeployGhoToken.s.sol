// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {Helpers} from './Helpers.sol';
import './Constants.sol';

contract DeployGhoToken is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY_GHO_TOKEN');
    // console2.log(deployerPrivateKey);

    vm.startBroadcast(deployerPrivateKey);

    Helpers.deployGhoToken(AaveGovernanceV2.SHORT_EXECUTOR);

    vm.stopBroadcast();
  }
}
