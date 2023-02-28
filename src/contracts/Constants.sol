// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Contrants library
 * @author Aave
 * @notice Defines the Reserve Constants for the Gho AIP
 */
library GhoConstants {
  uint8 public constant GHO_DECIMALS = 18;
  string public constant ATOKEN_NAME = 'Aave Ethereum GHO';
  string public constant ATOKEN_SYMBOL = 'aEthGHO';
  string public constant VDTOKEN_NAME = 'Aave Ethereum Variable Debt GHO';
  string public constant VDTOKEN_SYMBOL = 'variableDebtEthGHO';
  string public constant SDTOKEN_NAME = 'Aave Ethereum Stable Debt GHO';
  string public constant SDTOKEN_SYMBOL = 'stableDebtEthGHO';

  uint8 public constant EMODE_CATEGORY = 1; // Stablecoins

  uint256 public constant RESERVE_FACTOR = 1000;
  uint256 public constant LTV = 0;
  uint256 public constant LIQUIDATION_THRESHOLD = 0;
  uint256 public constant LIQUIDATION_BONUS = 0;
  uint256 public constant LIQ_PROTOCOL_FEE = 1000; // 10%
  uint256 public constant DEBT_CEILING = 2_000_000_00; // 2m
}
