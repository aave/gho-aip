address constant GHO_TOKEN_OWNER = 0xEE56e2B3D491590B5b31738cC34d5232F378a8D5; // SHORT EXECUTOR
address constant GHO_TOKEN = address(1);
address constant GHO_FLASHMINTER = address(1);
address constant GHO_ORACLE = address(1);
address constant GHO_ATOKEN = address(1);
address constant GHO_VARIABLE_DEBT_TOKEN = address(1);
address constant GHO_STABLE_DEBT_TOKEN = address(1);
address constant GHO_INTEREST_RATE_STRATEGY = address(1);
address constant GHO_DISCOUNT_RATE_STRATEGY = address(1);

// Risk Params
string constant FACILITATOR_AAVE_LABEL = 'Aave Ethereum V3 Pool';
uint256 constant FACILITATOR_AAVE_BUCKET_CAPACITY = 100_000_000e18;
string constant FACILITATOR_FLASHMINTER_LABEL = 'FlashMinter Facilitator';
uint256 constant FACILITATOR_FLASHMINTER_BUCKET_CAPACITY = 2_000_000e18;
uint256 constant VARIABLE_BORROW_RATE = 0.0150e27; // 1.50%
uint256 constant FLASHMINT_FEE = 0; // 0%
uint256 constant GHO_DISCOUNTED_PER_DISCOUNT_TOKEN = 100e18;
uint256 constant DISCOUNT_RATE = 0.3e4;
uint256 constant MIN_DISCOUNT_TOKEN_BALANCE = 1e15;
uint256 constant MIN_DEBT_TOKEN_BALANCE = 1e18;
