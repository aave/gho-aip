// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/console.sol';

import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {GhoAToken} from 'gho-core/src/contracts/gho/GhoToken.sol';

// import {AaveV3EthereumEModes} from './AaveV3EthereumConfigs.sol';
import {ProtocolV3_0_1TestBase, ReserveConfig, ReserveTokens} from 'aave-helpers/src/ProtocolV3TestBase.sol';

import {IPoolConfigurator, ConfiguratorInputTypes} from 'aave-address-book/AaveV3.sol';
import {AaveV3ListingEthereum} from 'aave-helpers/src/v3-listing-engine/AaveV3ListingEthereum.sol';
import {GenericV3ListingEngine} from 'aave-helpers/src/v3-listing-engine/GenericV3ListingEngine.sol';
// import {AaveV3GhoListing} from '../src/contracts/AaveV3GhoListing.sol';

// import {AaveV3EthereumGHOPayload} from '../src/contracts/AaveV3EthereumGHOPayload.sol';
import {TestWithExecutor} from 'aave-helpers/src/GovHelpers.sol';

contract AaveV3EthGhoUSDPayloadTest is ProtocolV3_0_1TestBase, TestWithExecutor {
  using stdStorage for StdStorage;

  address public constant GHO_ATOKEN = 0x946541093fC2dE445161dD0A67b8524d1FBc5428;
  address public constant GHO_VARIABLE_DEBT_TOKEN = 0x5B3f652d1B8e9D28F351DCE75993eD4d6Efc3F78;
  address public constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;

  // the identifiers of the forks
  uint256 mainnetFork;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 16633440);
    _selectPayloadExecutor(AaveGovernanceV2.SHORT_EXECUTOR);

    GhoAToken ghoAtoken = new GhoAToken(
      AaveV3Ethereum.POOL,
      ZERO_ADDRESS, // treasury
      ZERO_ADDRESS, // underlyingAsset
      ZERO_ADDRESS, // incentivesController
      0, // aTokenDecimals
      'ATOKEN_IMPL', // aTokenName
      'ATOKEN_IMPL', // aTokenSymbol
      '0x10' // params
    );
  }
}
