// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {GhoOracle} from 'gho-core/facilitators/aave/oracle/GhoOracle.sol';
import {GhoAToken} from 'gho-core/facilitators/aave/tokens/GhoAToken.sol';
import {GhoVariableDebtToken} from 'gho-core/facilitators/aave/tokens/GhoVariableDebtToken.sol';
import {GhoInterestRateStrategy} from 'gho-core/facilitators/aave/interestStrategy/GhoInterestRateStrategy.sol';
import {GhoDiscountRateStrategy} from 'gho-core/facilitators/aave/interestStrategy/GhoDiscountRateStrategy.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';

contract DeployFacilitatorAave is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

    vm.startBroadcast(deployerPrivateKey);

    GhoOracle ghoOracle = new GhoOracle();
    GhoAToken ghoAtoken = new GhoAToken(IPool(address(AaveV3Ethereum.POOL)));
    GhoVariableDebtToken ghoVariableDebtToken = new GhoVariableDebtToken(
      IPool(address(AaveV3Ethereum.POOL))
    );
    GhoInterestRateStrategy ghoInterestRateStrategy = new GhoInterestRateStrategy(25);
    GhoDiscountRateStrategy ghoDiscountRateStrategy = new GhoDiscountRateStrategy();
    vm.stopBroadcast();
  }
}
