// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

address constant GHO_ORACLE = 0xD110cac5d8682A3b045D5524a9903E031d70FCCd;
address constant GHO_ATOKEN = 0x2f32A274e02FA356423CE5e97a8e3155c1Ac396b;
address constant GHO_VARIABLE_DEBT_TOKEN = 0x3FEaB6F8510C73E05b8C0Fdf96Df012E3A144319;
address constant GHO_STABLE_DEBT_TOKEN = 0x05b435C741F5ab03C2E6735e23f1b7Fe01Cc6b22;
address constant GHO_INTEREST_RATE_STRATEGY = 0x16E77D8a7192b65fEd49B3374417885Ff4421A74;
address constant GHO_DISCOUNT_RATE_STRATEGY = 0x4C38Ec4D1D2068540DfC11DFa4de41F733DDF812;
address constant PAYLOAD = 0x16765d275c00Caa7Ec9a30D1629fD42121c3ae6B;
bytes32 constant IPFS_HASH = bytes32(0);

// Risk Params
string constant FACILITATOR_AAVE_LABEL = 'Aave V3 Ethereum Pool';
uint256 constant FACILITATOR_AAVE_BUCKET_CAPACITY = 100_000_000e18;
string constant FACILITATOR_FLASHMINTER_LABEL = 'FlashMinter Facilitator';
uint256 constant FACILITATOR_FLASHMINTER_BUCKET_CAPACITY = 2_000_000e18;
uint256 constant VARIABLE_BORROW_RATE = 0.0150e27; // 1.50%
uint256 constant FLASHMINT_FEE = 0; // 0%
uint256 constant GHO_DISCOUNTED_PER_DISCOUNT_TOKEN = 100e18;
uint256 constant DISCOUNT_RATE = 0.3e4;
uint256 constant MIN_DISCOUNT_TOKEN_BALANCE = 1e15;
uint256 constant MIN_DEBT_TOKEN_BALANCE = 1e18;
uint256 constant LTV = 0;
uint256 constant LIQUIDATION_THRESHOLD = 0;
uint256 constant LIQUIDATION_BONUS = 0;
uint256 constant LIQ_PROTOCOL_FEE = 0;
uint256 constant RESERVE_FACTOR = 0;
uint256 constant DEBT_CEILING = 0;
