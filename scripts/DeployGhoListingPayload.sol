// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import {GhoListingPayload} from '../src/contracts/GhoListingPayload.sol';
import {Helpers} from './Helpers.sol';
import './Constants.sol';

contract DeployGhoListingPayload is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

    vm.startBroadcast(deployerPrivateKey);

    Helpers.deployListingPayload(
      GHO_ORACLE,
      GHO_ATOKEN,
      GHO_VARIABLE_DEBT_TOKEN,
      GHO_STABLE_DEBT_TOKEN,
      GHO_INTEREST_RATE_STRATEGY,
      GHO_DISCOUNT_RATE_STRATEGY
    );

    vm.stopBroadcast();
  }
}
