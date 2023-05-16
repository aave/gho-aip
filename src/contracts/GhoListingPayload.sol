// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {ConfiguratorInputTypes} from 'aave-address-book/AaveV3.sol';
import {IStakedAaveV3} from 'aave-stk-v1-5/interfaces/IStakedAaveV3.sol';
import {IGhoVariableDebtTokenTransferHook} from 'aave-stk-v1-5/interfaces/IGhoVariableDebtTokenTransferHook.sol';
import {GhoToken} from 'gho-core/gho/GhoToken.sol';
import {IGhoAToken} from 'gho-core/facilitators/aave/tokens/interfaces/IGhoAToken.sol';
import {IGhoVariableDebtToken} from 'gho-core/facilitators/aave/tokens/interfaces/IGhoVariableDebtToken.sol';

interface IProposalGenericExecutor {
  function execute() external;
}

contract GhoListingPayload is IProposalGenericExecutor {
  bytes32 public constant FACILITATOR_MANAGER = keccak256('FACILITATOR_MANAGER');
  bytes32 public constant BUCKET_MANAGER = keccak256('BUCKET_MANAGER');

  string public constant FACILITATOR_AAVE_LABEL = 'Aave Ethereum V3 Pool';
  uint128 public constant FACILITATOR_AAVE_BUCKET_CAPACITY = 50_000_000 * 1e18;
  string public constant FACILITATOR_FLASHMINTER_LABEL = 'GHO FlashMinter';
  uint128 public constant FACILITATOR_FLASHMINTER_BUCKET_CAPACITY = 1_000_000 * 1e18;

  uint8 public constant GHO_DECIMALS = 18;
  string public constant ATOKEN_NAME = 'Aave Ethereum GHO';
  string public constant ATOKEN_SYMBOL = 'aEthGHO';
  string public constant VDTOKEN_NAME = 'Aave Ethereum Variable Debt GHO';
  string public constant VDTOKEN_SYMBOL = 'variableDebtEthGHO';
  string public constant SDTOKEN_NAME = 'Aave Ethereum Stable Debt GHO';
  string public constant SDTOKEN_SYMBOL = 'stableDebtEthGHO';
  uint256 public constant LTV = 0;
  uint256 public constant LIQUIDATION_THRESHOLD = 0;
  uint256 public constant LIQUIDATION_BONUS = 0;
  uint256 public constant LIQ_PROTOCOL_FEE = 0;
  uint256 public constant RESERVE_FACTOR = 0;
  uint256 public constant DEBT_CEILING = 0;

  address public constant STK_AAVE = 0x4da27a545c0c5B758a6BA100e3a049001de870f5;

  address public immutable GHO_TOKEN;
  address public immutable GHO_FLASHMINTER;
  address public immutable GHO_ORACLE;

  address public immutable GHO_ATOKEN_IMPL;
  address public immutable GHO_VARIABLE_DEBT_TOKEN_IMPL;
  address public immutable GHO_STABLE_DEBT_TOKEN_IMPL;
  address public immutable GHO_INTEREST_RATE_STRATEGY;
  address public immutable GHO_DISCOUNT_RATE_STRATEGY;

  constructor(
    address ghoToken,
    address ghoFlashMinter,
    address ghoOracle,
    address ghoATokenImpl,
    address ghoVariableDebtTokenImpl,
    address ghoStableDebtTokenImpl,
    address ghoInterestRateStrategy,
    address ghoDiscountRateStrategy
  ) {
    GHO_TOKEN = ghoToken;
    GHO_FLASHMINTER = ghoFlashMinter;
    GHO_ORACLE = ghoOracle;
    GHO_ATOKEN_IMPL = ghoATokenImpl;
    GHO_VARIABLE_DEBT_TOKEN_IMPL = ghoVariableDebtTokenImpl;
    GHO_STABLE_DEBT_TOKEN_IMPL = ghoStableDebtTokenImpl;
    GHO_INTEREST_RATE_STRATEGY = ghoInterestRateStrategy;
    GHO_DISCOUNT_RATE_STRATEGY = ghoDiscountRateStrategy;
  }

  function execute() external override {
    // ------------------------------------------------
    // 1. Grant roles to SHORT EXECUTOR
    // ------------------------------------------------
    GhoToken(GHO_TOKEN).grantRole(FACILITATOR_MANAGER, address(this));
    GhoToken(GHO_TOKEN).grantRole(BUCKET_MANAGER, address(this));

    // ------------------------------------------------
    // 2. Setting oracle for GHO
    // ------------------------------------------------
    address[] memory assets = new address[](1);
    assets[0] = GHO_TOKEN;
    address[] memory sources = new address[](1);
    sources[0] = GHO_ORACLE;

    AaveV3Ethereum.ORACLE.setAssetSources(assets, sources);

    // ------------------------------------------------
    // 3. Listing of GHO as borrowable asset
    // ------------------------------------------------
    ConfiguratorInputTypes.InitReserveInput[]
      memory initReserveInputs = new ConfiguratorInputTypes.InitReserveInput[](1);

    initReserveInputs[0] = ConfiguratorInputTypes.InitReserveInput({
      aTokenImpl: GHO_ATOKEN_IMPL,
      stableDebtTokenImpl: GHO_STABLE_DEBT_TOKEN_IMPL,
      variableDebtTokenImpl: GHO_VARIABLE_DEBT_TOKEN_IMPL,
      underlyingAssetDecimals: GHO_DECIMALS,
      interestRateStrategyAddress: GHO_INTEREST_RATE_STRATEGY,
      underlyingAsset: GHO_TOKEN,
      treasury: AaveV3Ethereum.COLLECTOR,
      incentivesController: AaveV3Ethereum.DEFAULT_INCENTIVES_CONTROLLER,
      aTokenName: ATOKEN_NAME,
      aTokenSymbol: ATOKEN_SYMBOL,
      variableDebtTokenName: VDTOKEN_NAME,
      variableDebtTokenSymbol: VDTOKEN_SYMBOL,
      stableDebtTokenName: SDTOKEN_NAME,
      stableDebtTokenSymbol: SDTOKEN_SYMBOL,
      params: bytes('') //    params: '0x10',
    });

    AaveV3Ethereum.POOL_CONFIGURATOR.initReserves(initReserveInputs);

    AaveV3Ethereum.POOL_CONFIGURATOR.setReserveBorrowing(GHO_TOKEN, true);

    // ------------------------------------------------
    // 4. Configuration of GhoAToken and GhoDebtToken
    // ------------------------------------------------
    (address ghoATokenAddress, , address ghoVariableDebtTokenAddress) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveTokensAddresses(GHO_TOKEN);

    // GhoAToken config
    IGhoAToken(ghoATokenAddress).setVariableDebtToken(ghoVariableDebtTokenAddress);
    IGhoAToken(ghoATokenAddress).updateGhoTreasury(AaveV3Ethereum.COLLECTOR);

    // GhoVariableDebtToken config
    IGhoVariableDebtToken(ghoVariableDebtTokenAddress).setAToken(ghoATokenAddress);
    IGhoVariableDebtToken(ghoVariableDebtTokenAddress).updateDiscountRateStrategy(
      GHO_DISCOUNT_RATE_STRATEGY
    );
    IGhoVariableDebtToken(ghoVariableDebtTokenAddress).updateDiscountToken(STK_AAVE);

    // ------------------------------------------------
    // 5. Configuration of STKAAVE Hook
    // ------------------------------------------------
    IStakedAaveV3(STK_AAVE).setGHODebtToken(
      IGhoVariableDebtTokenTransferHook(ghoVariableDebtTokenAddress)
    );

    // ------------------------------------------------
    // 6. Registration of AaveFacilitator
    // ------------------------------------------------
    GhoToken(GHO_TOKEN).addFacilitator(
      ghoATokenAddress,
      FACILITATOR_AAVE_LABEL,
      FACILITATOR_AAVE_BUCKET_CAPACITY
    );

    // ------------------------------------------------
    // 7. Registration of FlashMinter
    // ------------------------------------------------
    GhoToken(GHO_TOKEN).addFacilitator(
      GHO_FLASHMINTER,
      FACILITATOR_FLASHMINTER_LABEL,
      FACILITATOR_FLASHMINTER_BUCKET_CAPACITY
    );
  }
}
