// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {ConfiguratorInputTypes} from 'aave-address-book/AaveV3.sol';
import {IStakedAaveV3} from 'aave-stk-v1-5/interfaces/IStakedAaveV3.sol';
import {IGhoVariableDebtTokenTransferHook} from 'aave-stk-v1-5/interfaces/IGhoVariableDebtTokenTransferHook.sol';
import {IGhoAToken} from 'gho-core/facilitators/aave/tokens/interfaces/IGhoAToken.sol';
import {IGhoVariableDebtToken} from 'gho-core/facilitators/aave/tokens/interfaces/IGhoVariableDebtToken.sol';
import {GhoFlashMinter} from 'gho-core/facilitators/flashMinter/GhoFlashMinter.sol';
import {GhoToken} from 'gho-core/gho/GhoToken.sol';

interface IProposalGenericExecutor {
  function execute() external;
}

contract GhoListingPayload is IProposalGenericExecutor {
  // Deployments
  address public constant CREATE2_SINGLETON_FACTORY = 0x2401ae9bBeF67458362710f90302Eb52b5Ce835a;
  bytes32 public constant CREATE2_SALT = bytes32(0);
  address public GHO_TOKEN; // Deployed at AIP execution time
  address public GHO_FLASHMINTER; // Deployed at AIP execution time

  // GHO Token
  bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
  bytes32 public constant FACILITATOR_MANAGER = keccak256('FACILITATOR_MANAGER');
  bytes32 public constant BUCKET_MANAGER = keccak256('BUCKET_MANAGER');

  // Aave Facilitator
  string public constant FACILITATOR_AAVE_LABEL = 'Aave Ethereum V3 Pool';
  uint128 public constant FACILITATOR_AAVE_BUCKET_CAPACITY = 100_000_000 * 1e18;

  // GHO FlashMinter Facilitator
  string public constant FACILITATOR_FLASHMINTER_LABEL = 'FlashMinter Facilitator';
  uint128 public constant FACILITATOR_FLASHMINTER_BUCKET_CAPACITY = 2_000_000 * 1e18;
  uint128 public constant FLASHMINTER_FEE = 0;

  // GHO Listing
  uint8 public constant GHO_DECIMALS = 18;
  string public constant ATOKEN_NAME = 'Aave Ethereum GHO';
  string public constant ATOKEN_SYMBOL = 'aEthGHO';
  string public constant VDTOKEN_NAME = 'Aave Ethereum Variable Debt GHO';
  string public constant VDTOKEN_SYMBOL = 'variableDebtEthGHO';
  string public constant SDTOKEN_NAME = 'Aave Ethereum Stable Debt GHO';
  string public constant SDTOKEN_SYMBOL = 'stableDebtEthGHO';

  address public immutable GHO_ORACLE;
  address public immutable GHO_ATOKEN_IMPL;
  address public immutable GHO_VARIABLE_DEBT_TOKEN_IMPL;
  address public immutable GHO_STABLE_DEBT_TOKEN_IMPL;
  address public immutable GHO_INTEREST_RATE_STRATEGY;
  address public immutable GHO_DISCOUNT_RATE_STRATEGY;

  address public constant STK_AAVE = 0x4da27a545c0c5B758a6BA100e3a049001de870f5;

  constructor(
    address ghoOracle,
    address ghoATokenImpl,
    address ghoVariableDebtTokenImpl,
    address ghoStableDebtTokenImpl,
    address ghoInterestRateStrategy,
    address ghoDiscountRateStrategy
  ) {
    GHO_ORACLE = ghoOracle;
    GHO_ATOKEN_IMPL = ghoATokenImpl;
    GHO_VARIABLE_DEBT_TOKEN_IMPL = ghoVariableDebtTokenImpl;
    GHO_STABLE_DEBT_TOKEN_IMPL = ghoStableDebtTokenImpl;
    GHO_INTEREST_RATE_STRATEGY = ghoInterestRateStrategy;
    GHO_DISCOUNT_RATE_STRATEGY = ghoDiscountRateStrategy;
  }

  function execute() external override {
    // ------------------------------------------------
    // 1. Deployment of GhoToken
    // ------------------------------------------------
    GHO_TOKEN = _deployCreate2(
      abi.encodePacked(type(GhoToken).creationCode, abi.encode(AaveGovernanceV2.SHORT_EXECUTOR))
    );
    require(GHO_TOKEN == precomputeGhoTokenAddress(), 'UNEXPECTED_GHO_TOKEN_ADDRESS');
    require(
      GhoToken(GHO_TOKEN).hasRole(DEFAULT_ADMIN_ROLE, address(this)),
      'UNEXPECTED_GHO_DEPLOY_INIT'
    );
    GhoToken(GHO_TOKEN).grantRole(FACILITATOR_MANAGER, address(this));
    GhoToken(GHO_TOKEN).grantRole(BUCKET_MANAGER, address(this));

    // ------------------------------------------------
    // 2. Deployment of GhoFlashMinter
    // ------------------------------------------------
    GHO_FLASHMINTER = _deployCreate2(
      abi.encodePacked(
        type(GhoFlashMinter).creationCode,
        abi.encode(
          precomputeGhoTokenAddress(),
          AaveV3Ethereum.COLLECTOR,
          FLASHMINTER_FEE,
          address(AaveV3Ethereum.POOL_ADDRESSES_PROVIDER)
        )
      )
    );
    require(
      GHO_FLASHMINTER == precomputeGhoFlashMinterAddress(),
      'UNEXPECTED_GHO_FLASHMINTER_ADDRESS'
    );
    require(
      address(GhoFlashMinter(GHO_FLASHMINTER).GHO_TOKEN()) == GHO_TOKEN,
      'UNEXPECTED_GHO_FLASHMINTER_DEPLOY_INIT1'
    );
    require(
      GhoFlashMinter(GHO_FLASHMINTER).getFee() == FLASHMINTER_FEE,
      'UNEXPECTED_GHO_FLASHMINTER_DEPLOY_INIT2'
    );
    require(
      GhoFlashMinter(GHO_FLASHMINTER).getGhoTreasury() == AaveV3Ethereum.COLLECTOR,
      'UNEXPECTED_GHO_FLASHMINTER_DEPLOY_INIT3'
    );
    require(
      address(GhoFlashMinter(GHO_FLASHMINTER).ADDRESSES_PROVIDER()) ==
        address(AaveV3Ethereum.POOL_ADDRESSES_PROVIDER),
      'UNEXPECTED_GHO_FLASHMINTER_DEPLOY_INIT4'
    );

    // ------------------------------------------------
    // 3. Setting oracle for GHO
    // ------------------------------------------------
    address[] memory assets = new address[](1);
    assets[0] = GHO_TOKEN;
    address[] memory sources = new address[](1);
    sources[0] = GHO_ORACLE;

    AaveV3Ethereum.ORACLE.setAssetSources(assets, sources);

    // ------------------------------------------------
    // 4. Listing of GHO as borrowable asset
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
    // 5. Configuration of GhoAToken and GhoDebtToken
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
    // 6. Configuration of STKAAVE Hook
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

  /**
   * @notice Returns the precomputed address of GHO token
   * @return The precomputed address of the GhoToken
   */
  function precomputeGhoTokenAddress() public pure returns (address) {
    return
      _precomputeAddress(
        abi.encodePacked(type(GhoToken).creationCode, abi.encode(AaveGovernanceV2.SHORT_EXECUTOR))
      );
  }

  /**
   * @notice Returns the precomputed address of the GHO FlashMinter
   * @return The precomputed address of the GhoFlashMinter
   */
  function precomputeGhoFlashMinterAddress() public pure returns (address) {
    return
      _precomputeAddress(
        abi.encodePacked(
          type(GhoFlashMinter).creationCode,
          abi.encode(
            precomputeGhoTokenAddress(),
            AaveV3Ethereum.COLLECTOR,
            FLASHMINTER_FEE,
            address(AaveV3Ethereum.POOL_ADDRESSES_PROVIDER)
          )
        )
      );
  }

  function _precomputeAddress(bytes memory bytecode) internal pure returns (address) {
    return
      address(
        uint160(
          uint(
            keccak256(
              abi.encodePacked(
                bytes1(0xff),
                CREATE2_SINGLETON_FACTORY,
                CREATE2_SALT,
                keccak256(bytecode)
              )
            )
          )
        )
      );
  }

  function _deployCreate2(bytes memory bytecode) internal returns (address) {
    (bool success, bytes memory returnData) = CREATE2_SINGLETON_FACTORY.call(
      abi.encodePacked(CREATE2_SALT, bytecode)
    );
    require(success, 'CREATE2_DEPLOYMENT_FAILED');
    return address(bytes20(returnData));
  }
}
