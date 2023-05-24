address constant GHO_ORACLE = address(1);
address constant GHO_ATOKEN = address(1);
address constant GHO_VARIABLE_DEBT_TOKEN = address(1);
address constant GHO_STABLE_DEBT_TOKEN = address(1);
address constant GHO_INTEREST_RATE_STRATEGY = address(1);
address constant GHO_DISCOUNT_RATE_STRATEGY = address(1);
address constant PAYLOAD = address(1);
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
