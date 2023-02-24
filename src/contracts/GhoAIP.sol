// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;
import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';

import {IPoolConfigurator, IAaveOracle, ConfiguratorInputTypes} from 'aave-address-book/AaveV3.sol';

// https://etherscan.io/address/0xe0070f7a961dcb102e3d904a170613be3f3b37a9#code
interface Initializable {
  function initialize(
    uint8 underlyingAssetDecimals,
    string calldata tokenName,
    string calldata tokenSymbol
  ) external;
}

interface IProposalGenericExecutor {
  function execute() external;
}

contract GhoListingPayload is IProposalGenericExecutor {
  address public constant GHO_TOKEN = 0xfd7dF17EF5Baa6460204D95B4F00e355e5B77544;
  uint8 public constant GHO_DECIMALS = 18;

  address public constant GHO_ORACLE = 0x4Cfed366cfD75Ec739e0d763f557680Bc656a965;

  address public constant GHO_ATOKEN = 0x946541093fC2dE445161dD0A67b8524d1FBc5428;
  address public constant GHO_VARIABLE_DEBT_TOKEN = 0x5B3f652d1B8e9D28F351DCE75993eD4d6Efc3F78;

  address public constant ATOKEN_IMPL = 0x946541093fC2dE445161dD0A67b8524d1FBc5428;
  address public constant VARIABLE_DEBT_IMPL = 0x5B3f652d1B8e9D28F351DCE75993eD4d6Efc3F78;
  address public constant STABLE_DEBT_IMPL = 0x595c33538215DC4B092F35Afc85d904631263f4F;
  address public constant INTEREST_RATE_STRATEGY = 0xcA20515e8fB92Ec70eaDa5c0Ad5A502bCab1B2E0;

  string public constant ATOKEN_NAME = 'Aave Ethereum GHO';
  string public constant ATOKEN_SYMBOL = 'aEthGHO';
  string public constant VDTOKEN_NAME = 'Aave Ethereum Variable Debt GHO';
  string public constant VDTOKEN_SYMBOL = 'variableDebtEthGHO';
  string public constant SDTOKEN_NAME = 'Aave Ethereum Stable Debt GHO';
  string public constant SDTOKEN_SYMBOL = 'stableDebtEthGHO';

  uint256 public constant RESERVE_FACTOR = 1000;
  uint256 public constant LTV = 0;
  uint256 public constant LIQUIDATION_THRESHOLD = 0;
  uint256 public constant LIQUIDATION_BONUS = 0;

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
    // 2. Listing of stMATIC, with all its configurations
    // ------------------------------------------------

    ConfiguratorInputTypes.InitReserveInput[]
      memory initReserveInputs = new ConfiguratorInputTypes.InitReserveInput[](1);

    initReserveInputs[0] = ConfiguratorInputTypes.InitReserveInput({
      aTokenImpl: GHO_ATOKEN,
      stableDebtTokenImpl: STABLE_DEBT_IMPL,
      variableDebtTokenImpl: GHO_VARIABLE_DEBT_TOKEN,
      underlyingAssetDecimals: GHO_DECIMALS,
      interestRateStrategyAddress: INTEREST_RATE_STRATEGY,
      underlyingAsset: 0xfd7dF17EF5Baa6460204D95B4F00e355e5B77544,
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

    IPoolConfigurator configurator = AaveV3Ethereum.POOL_CONFIGURATOR;

    configurator.initReserves(initReserveInputs);

    configurator.setReserveBorrowing(GHO_TOKEN, true);
    // configurator.setReserveFactor(GHO_TOKEN, RESERVE_FACTOR);

    // We initialize the different implementations, for security reasons
    // Initializable(ATOKEN_IMPL).initialize(uint8(18), 'Aave interest bearing LUSD', 'aLUSD');
    // Initializable(VARIABLE_DEBT_IMPL).initialize(
    //   uint8(18),
    //   'Aave variable debt bearing LUSD',
    //   'variableDebtLUSD'
    // );
    // Initializable(STABLE_DEBT_IMPL).initialize(
    //   uint8(18),
    //   'Aave stable debt bearing LUSD',
    //   'stableDebtLUSD'
    // );
  }
}
