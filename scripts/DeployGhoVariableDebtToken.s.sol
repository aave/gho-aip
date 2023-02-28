// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {GhoVariableDebtToken} from 'gho-core/src/contracts/facilitators/aave/tokens/GhoVariableDebtToken.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';

import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {GhoAToken} from 'gho-core/src/contracts/facilitators/aave/tokens/GhoAToken.sol';
import {GhoOracle} from 'gho-core/src/contracts/facilitators/aave/oracle/GhoOracle.sol';
import {GhoToken} from 'gho-core/src/contracts/gho/GhoToken.sol';
import {GhoInterestRateStrategy} from 'gho-core/src/contracts/facilitators/aave/interestStrategy/GhoInterestRateStrategy.sol';
import {GhoVariableDebtToken} from 'gho-core/src/contracts/facilitators/aave/tokens/GhoVariableDebtToken.sol';
import {ProtocolV3_0_1TestBase, ReserveConfig, ReserveTokens} from 'aave-helpers/src/ProtocolV3TestBase.sol';

contract Deploy is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

    vm.startBroadcast(deployerPrivateKey);

    GhoVariableDebtToken ghoVariableDebtToken = new GhoVariableDebtToken(
      IPool(address(AaveV3Ethereum.POOL))
    );

    vm.stopBroadcast();
  }
}
