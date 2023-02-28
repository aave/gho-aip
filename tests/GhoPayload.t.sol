// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/console.sol';

import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {GhoAToken} from 'gho-core/src/contracts/facilitators/aave/tokens/GhoAToken.sol';
import {GhoOracle} from 'gho-core/src/contracts/facilitators/aave/oracle/GhoOracle.sol';
import {GhoToken} from 'gho-core/src/contracts/gho/GhoToken.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {StableDebtToken} from '@aave/core-v3/contracts/protocol/tokenization/StableDebtToken.sol';
import {GhoConstants} from '../src/contracts/Constants.sol';

import {GhoInterestRateStrategy} from 'gho-core/src/contracts/facilitators/aave/interestStrategy/GhoInterestRateStrategy.sol';
import {GhoVariableDebtToken} from 'gho-core/src/contracts/facilitators/aave/tokens/GhoVariableDebtToken.sol';
import {ProtocolV3_0_1TestBase, ReserveConfig, ReserveTokens} from 'aave-helpers/src/ProtocolV3TestBase.sol';
import {GhoListingPayload} from '../src/contracts/GhoAIP.sol';
import {TestWithExecutor} from 'aave-helpers/src/GovHelpers.sol';

contract AaveV3EthGhoUSDPayloadTest is ProtocolV3_0_1TestBase, TestWithExecutor {
  using stdStorage for StdStorage;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 16721514);
    _selectPayloadExecutor(AaveGovernanceV2.SHORT_EXECUTOR);
  }

  function testExecute() public {
    GhoAToken ghoAtoken = new GhoAToken(IPool(address(AaveV3Ethereum.POOL)));

    GhoOracle ghoOracle = new GhoOracle();

    GhoToken ghoToken = new GhoToken();

    GhoVariableDebtToken ghoVariableDebtToken = new GhoVariableDebtToken(
      IPool(address(AaveV3Ethereum.POOL))
    );

    GhoInterestRateStrategy ghoInterestRateStrategy = new GhoInterestRateStrategy(25); // variable borrow rate expressed in ray

    StableDebtToken ghoStableDebtToken = new StableDebtToken(IPool(address(AaveV3Ethereum.POOL)));

    GhoListingPayload ghoAip = new GhoListingPayload(
      address(ghoAtoken),
      address(ghoStableDebtToken),
      address(ghoVariableDebtToken),
      address(ghoInterestRateStrategy),
      address(ghoToken),
      address(ghoOracle)
    );

    vm.startPrank(AaveV3Ethereum.ACL_ADMIN);
    AaveV3Ethereum.ACL_MANAGER.addPoolAdmin(address(ghoAip));
    vm.stopPrank();

    ReserveConfig[] memory allConfigsBefore = _getReservesConfigs(AaveV3Ethereum.POOL);

    // createConfigurationSnapshot('preGhoUSD', AaveV3Ethereum.POOL);
    ghoAip.execute();
    // createConfigurationSnapshot('postGhoUSD', AaveV3Ethereum.POOL);

    ReserveConfig[] memory allConfigsAfter = _getReservesConfigs(AaveV3Ethereum.POOL);

    ReserveConfig memory expectedAssetConfig = ReserveConfig({
      symbol: 'GHO',
      underlying: address(ghoToken),
      aToken: address(ghoAtoken),
      variableDebtToken: address(ghoVariableDebtToken),
      stableDebtToken: address(ghoStableDebtToken),
      decimals: GhoConstants.GHO_DECIMALS,
      ltv: GhoConstants.LTV,
      liquidationThreshold: GhoConstants.LIQUIDATION_THRESHOLD,
      liquidationBonus: GhoConstants.LIQUIDATION_BONUS,
      liquidationProtocolFee: GhoConstants.LIQ_PROTOCOL_FEE,
      reserveFactor: GhoConstants.RESERVE_FACTOR,
      usageAsCollateralEnabled: false,
      borrowingEnabled: true,
      interestRateStrategy: _findReserveConfigBySymbol(allConfigsAfter, 'GHO').interestRateStrategy,
      stableBorrowRateEnabled: false,
      isActive: true,
      isFrozen: false,
      isSiloed: false,
      isBorrowableInIsolation: false,
      isFlashloanable: true,
      supplyCap: 0,
      borrowCap: 0,
      debtCeiling: 0,
      eModeCategory: 1
    });

    _validateReserveConfig(expectedAssetConfig, allConfigsAfter);

    _noReservesConfigsChangesApartNewListings(allConfigsBefore, allConfigsAfter);

    _validateReserveTokensImpls(
      AaveV3Ethereum.POOL_ADDRESSES_PROVIDER,
      _findReserveConfigBySymbol(allConfigsAfter, 'GHO'),
      ReserveTokens({
        aToken: address(ghoAtoken),
        stableDebtToken: address(ghoStableDebtToken),
        variableDebtToken: address(ghoVariableDebtToken)
      })
    );

    _validateAssetSourceOnOracle(
      AaveV3Ethereum.POOL_ADDRESSES_PROVIDER,
      address(ghoToken),
      address(ghoOracle)
    );
  }
}
