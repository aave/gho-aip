// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';

import {IPoolConfigurator, IAaveOracle, ConfiguratorInputTypes} from 'aave-address-book/AaveV3.sol';
import {GhoConstants} from './constants.sol';
import 'forge-std/console.sol';

interface IProposalGenericExecutor {
  function execute() external;
}

contract GhoListingPayload is IProposalGenericExecutor {
  address public GHO_TOKEN;
  address public GHO_ORACLE;

  address public GHO_ATOKEN;
  address public GHO_VARIABLE_DEBT_TOKEN;

  address public VARIABLE_DEBT_IMPL;
  address public STABLE_DEBT_IMPL;
  address public INTEREST_RATE_STRATEGY;

  constructor(
    address ghoAToken,
    address stableDebtImpl,
    address ghoVariableDebtToken,
    address iRStrategy,
    address ghoToken,
    address ghoOracle
  ) {
    GHO_ATOKEN = address(ghoAToken);
    STABLE_DEBT_IMPL = address(stableDebtImpl);
    GHO_VARIABLE_DEBT_TOKEN = address(ghoVariableDebtToken);
    INTEREST_RATE_STRATEGY = address(iRStrategy);
    GHO_TOKEN = address(ghoToken);
    GHO_ORACLE = address(ghoOracle);
  }

  function execute() external override {
    // ----------------------------
    // 1. New price feed on oracle
    // ----------------------------
    address[] memory assets = new address[](1);
    assets[0] = GHO_TOKEN;
    address[] memory sources = new address[](1);
    sources[0] = GHO_ORACLE;

    AaveV3Ethereum.ORACLE.setAssetSources(assets, sources);

    // ------------------------------------------------
    // 2. Listing of gho, with all its configurations
    // ------------------------------------------------

    ConfiguratorInputTypes.InitReserveInput[]
      memory initReserveInputs = new ConfiguratorInputTypes.InitReserveInput[](1);

    initReserveInputs[0] = ConfiguratorInputTypes.InitReserveInput({
      aTokenImpl: GHO_ATOKEN,
      stableDebtTokenImpl: STABLE_DEBT_IMPL,
      variableDebtTokenImpl: GHO_VARIABLE_DEBT_TOKEN,
      underlyingAssetDecimals: GhoConstants.GHO_DECIMALS,
      interestRateStrategyAddress: INTEREST_RATE_STRATEGY,
      underlyingAsset: GHO_TOKEN,
      treasury: AaveV3Ethereum.COLLECTOR,
      incentivesController: AaveV3Ethereum.DEFAULT_INCENTIVES_CONTROLLER,
      aTokenName: GhoConstants.ATOKEN_NAME,
      aTokenSymbol: GhoConstants.ATOKEN_SYMBOL,
      variableDebtTokenName: GhoConstants.VDTOKEN_NAME,
      variableDebtTokenSymbol: GhoConstants.VDTOKEN_SYMBOL,
      stableDebtTokenName: GhoConstants.SDTOKEN_NAME,
      stableDebtTokenSymbol: GhoConstants.SDTOKEN_SYMBOL,
      params: bytes('') //    params: '0x10',
    });

    IPoolConfigurator configurator = AaveV3Ethereum.POOL_CONFIGURATOR;

    configurator.initReserves(initReserveInputs);

    configurator.setReserveBorrowing(GHO_TOKEN, true);
    configurator.setReserveFactor(GHO_TOKEN, GhoConstants.RESERVE_FACTOR);

    // configurator.setSupplyCap(GHO_TOKEN, 0);

    configurator.setAssetEModeCategory(GHO_TOKEN, GhoConstants.EMODE_CATEGORY);

    configurator.setLiquidationProtocolFee(GHO_TOKEN, GhoConstants.LIQ_PROTOCOL_FEE);
    configurator.setReserveFlashLoaning(GHO_TOKEN, true);

    // configurator.setDebtCeiling(GHO_TOKEN, DEBT_CEILING);

    // configurator.configureReserveAsCollateral(
    //   GHO_TOKEN,
    //   LTV,
    //   LIQUIDATION_THRESHOLD,
    //   LIQUIDATION_BONUS
    // );
  }
}
