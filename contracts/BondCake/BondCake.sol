/**
 * @notice Allow BondCake to be compatible with latest EVM version.
 */
pragma solidity >=0.8.16;

/**
 * @notice Import openzeppelin libraries.
 */
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @notice Import BondCake libraries.
 */
import "./BondWorker.sol";

/**
 * @notice Define BondCake smart contract.
 */
contract BondCake is
	Initializable,
	ERC20Upgradeable,
	ERC20BurnableUpgradeable,
	PausableUpgradeable,
	OwnableUpgradeable,
	ReentrancyGuardUpgradeable
{
	/**
	 * @notice Enable SafeMath for uint256
	 */
	using SafeMathUpgradeable for uint256;

	/**
	 * @notice Use for div method.
	 */
	uint256 public constant PRECISION = 1e10;

	/**
	 * @notice Bond policy data type.
	 */
	struct BondPolicy {
		uint256 BOND_DURATION;
		uint256 BOND_WAITING_TIME;
		uint256 SCHEDULED_NEXT_DEPOSIT_START;
		uint256 SCHEDULED_NEXT_STAKE_START;
		uint256 ACTUAL_STAKE_START;
		bool BOND_CONFIG_INITIALIZED;
		bool BOND_UNSTAKED;
	}

	/**
	 * @notice Declare events
	 */
	event ConfiguredBondPolicy(
		address indexed actor,
		uint256 indexed bondIndex,
		uint256 waitingTime,
		uint256 bondDuration,
		uint256 scheduledNextDepositStart,
		uint256 scheduledNextStakeStart
	);
	event DepositedCake(
		address indexed actor,
		uint256 indexed bondIndex,
		uint256 amount
	);
	event WithdrewCake(
		address indexed actor,
		uint256 indexed bondIndex,
		uint256 amount
	);
	event ExchangedBond(
		address indexed actor,
		uint256 indexed bondIndex,
		uint256 payout
	);
	event StakedCake(
		address indexed actor,
		uint256 indexed bondIndex,
		uint256 totalStakedAmount
	);
	event UnstakedCake(
		address indexed actor,
		uint256 indexed bondIndex,
		uint256 totalunstakeAmount
	);

	/**
	 * @notice Declare rounds bond configs.
	 */
	mapping(uint256 => BondPolicy) public bondPolicy;

	/*
	 * @notice Binding Cake address.
	 */
	IERC20 public Cake;

	/**
	 * @notice Binding Cake compound staking pool address.
	 */
	address public CompoundCakePoolAddress;

	/**
	 * @notice Declare current bond index. This index will be linearly increase once new bond round is activated.
	 */
	uint256 public currentBondRound;

	/**
	 * @notice Declare current bond worker instance.
	 */
	BondWorker public currentBondWorker;

	/**
	 * @notice Declare BCAKE:CAKE exchange rate
	 */
	uint256 public exchangeRate;

	/**
	 * @notice Declare service fee collector address
	 */
	address payable public serviceFeePoolAddress;

	/**
	 * @notice Declare service fee
	 */
	uint256 public serviceFee;

	/**
	 * @notice Ensure the service is collected properly.
	 */
	modifier needToCollectServiceFee() {
		require(msg.value == serviceFee, "Error: service fee is required ;(");

		(bool transferred, ) = address(serviceFeePoolAddress).call{
			value: address(this).balance
		}("");

		require(transferred, "Error: oops ;(");

		_;
	}

	/**
	 * @notice Ensure the next bond round can be activated.
	 */
	modifier whenCanActivate() {
		/**
		 * @dev Ensure the previous bond round was finished before activating new round.
		 */
		require(
			bondPolicy[currentBondRound].BOND_UNSTAKED == true,
			"Error: must finish previous round."
		);

		_;
	}

	/**
	 * @notice Ensure current bond round must be initialized.
	 */
	modifier whenBondInitialized() {
		_;

		require(
			bondPolicy[currentBondRound].BOND_CONFIG_INITIALIZED,
			"Error: bond round must be initialized."
		);
	}

	/**
	 * @notice Ensure current operation is executed in deposit phase.
	 */
	modifier whenCanDepositAndWithdraw() {
		/**
		 * @dev Make sure the timestamp is greater than next lock start time.
		 */
		require(
			block.timestamp >=
				bondPolicy[currentBondRound].SCHEDULED_NEXT_DEPOSIT_START,
			"Error: must be in deposit phase."
		);

		/**
		 * @dev Make sure the timestamp is lower than next stake start time.
		 */
		require(
			block.timestamp <
				bondPolicy[currentBondRound].SCHEDULED_NEXT_STAKE_START,
			"Error: must be in deposit phase."
		);

		_;
	}

	/**
	 * @notice Ensure current operation is executed in stake phase.
	 */
	modifier whenCanStake() {
		/**
		 * @dev Make sure the bond staking phase is activated.
		 */
		require(
			block.timestamp >=
				bondPolicy[currentBondRound].SCHEDULED_NEXT_STAKE_START,
			"Error: must be in stake phase."
		);

		_;
	}

	/**
	 * @notice Ensure current operation is executed in unstake phase.
	 */
	modifier whenCanUnstake() {
		/**
		 * @dev Make sure the actual bond round is expired.
		 */
		require(
			block.timestamp >=
				bondPolicy[currentBondRound].ACTUAL_STAKE_START.add(
					bondPolicy[currentBondRound].BOND_DURATION
				),
			"Error: must be in unstake phase."
		);

		_;
	}

	/**
	 * @notice Ensure current operation is executed in exchange phase.
	 */
	modifier whenCanExchange() {
		/**
		 * @dev Also need the bond round to be finalized.
		 */
		require(
			bondPolicy[currentBondRound].BOND_UNSTAKED,
			"Error: bond round must be unstaked."
		);

		_;
	}

	/**
	 * @notice Public constructor to disable default initializers.
	 */
	/// @custom:oz-upgrades-unsafe-allow constructor
	constructor() {
		_disableInitializers();
	}

	/**
	 * @notice Initializer function.
	 */
	function initialize(address cakeAddress, address cakePoolAddress)
		public
		initializer
	{
		/**
		 * @dev Initialize.
		 */
		__ERC20_init("BondCake", "BCAKE");
		__ERC20Burnable_init();
		__Pausable_init();
		__Ownable_init();

		/**
		 * @dev Binding addresses.
		 */
		CompoundCakePoolAddress = cakePoolAddress;
		Cake = IERC20(cakeAddress);

		/**
		 * @dev Initialize BondWorker.
		 */
		currentBondRound = 0;
		currentBondWorker = new BondWorker(cakeAddress, cakePoolAddress);

		/*
		 * @dev Initialize and activate the very first bond round
		 */
		_configureBondPolicy(
			0, // first bond round
			1 days,
			30 minutes,
			block.timestamp.add(30 minutes),
			block.timestamp.add(60 minutes)
		);

		/**
		 * @dev Binding service configs
		 */
		serviceFeePoolAddress = payable(owner());
		serviceFee = 0.05 ether;

		/**
		 * @dev Approve cake transfer
		 */
		approveCakeTransfer();
	}

	/**
	 * @notice Inject Pausable modifier to make sure the token transfers comply with Pausable handler.
	 */
	function _beforeTokenTransfer(
		address from,
		address to,
		uint256 amount
	) internal override whenNotPaused {
		super._beforeTokenTransfer(from, to, amount);
	}

	/**
	 * @notice Configure next bond.
	 * @dev private method.
	 */
	function _configureBondPolicy(
		uint256 bondIndex,
		uint256 bondDuration,
		uint256 waitingTime,
		uint256 scheduledNextDepositStart,
		uint256 scheduledNextStakeStart
	) internal {
		/**
		 * @dev Configure bond round.
		 */
		bondPolicy[bondIndex].BOND_CONFIG_INITIALIZED = true;
		bondPolicy[bondIndex].BOND_DURATION = bondDuration;
		bondPolicy[bondIndex].BOND_WAITING_TIME = waitingTime;
		bondPolicy[bondIndex]
			.SCHEDULED_NEXT_DEPOSIT_START = scheduledNextDepositStart;
		bondPolicy[bondIndex]
			.SCHEDULED_NEXT_STAKE_START = scheduledNextStakeStart;

		/**
		 * @dev Validate.
		 */
		require(
			bondPolicy[bondIndex].SCHEDULED_NEXT_STAKE_START >
				bondPolicy[bondIndex].SCHEDULED_NEXT_DEPOSIT_START,
			"Error: bond timestamp must be greater than lock timestamp."
		);

		require(
			block.timestamp <
				bondPolicy[bondIndex].SCHEDULED_NEXT_DEPOSIT_START,
			"Error: lock timestamp must be greater than block timestamp."
		);

		require(
			scheduledNextStakeStart.sub(scheduledNextDepositStart) ==
				waitingTime,
			"Error: invalid waiting time"
		);

		/**
		 * @dev Emit event
		 */
		emit ConfiguredBondPolicy(
			msg.sender,
			bondIndex,
			waitingTime,
			bondDuration,
			scheduledNextDepositStart,
			scheduledNextStakeStart
		);
	}

	/**
	 * @notice Calculate BCAKE:CAKE exchange rate.
	 * @dev Calculate using current issued BCAKE compare with current native CAKE in the contract.
	 */
	function _calculateExchangeRate() internal view returns (uint256) {
		uint256 currentCakeBalance = Cake.balanceOf(address(this));
		uint256 totalBCake = totalSupply();

		/**
		 * @dev Return
		 */
		return currentCakeBalance.mul(PRECISION).div(totalBCake);
	}

	/**
	 * @notice Pause BondCake smart contract.
	 * @dev Only owner can pause the contract when the contract is not paused.
	 */
	function pause() public onlyOwner whenNotPaused {
		_pause();
	}

	/**
	 * @notice Unpause BondCake smart contract.
	 * @dev Only owner can unpause the contract when the contract is paused.
	 */
	function unpause() public onlyOwner whenPaused {
		_unpause();
	}

	/**
	 * @notice Configure next bond.
	 * @dev Only owner can configure.
	 */
	function configureBondPolicy(
		uint256 bondIndex,
		uint256 bondDuration,
		uint256 waitingTime,
		uint256 scheduledNextDepositStart,
		uint256 scheduledNextStakeStart
	) external onlyOwner {
		_configureBondPolicy(
			bondIndex,
			bondDuration,
			waitingTime,
			scheduledNextDepositStart,
			scheduledNextStakeStart
		);
	}

	/**
	 * @notice Configure service fee.
	 * @dev Only owner can configure.
	 */
	function configureServiceFee(
		address payable serviceFeeCollector,
		uint256 fee
	) external onlyOwner {
		serviceFeePoolAddress = serviceFeeCollector;
		serviceFee = fee;
	}

	/**
	 * @notice Emergency withdraw Cake to protect users funds.
	 * @dev Only owner can call.
	 */
	function emergencyWithdraw() external onlyOwner {
		Cake.transfer(owner(), Cake.balanceOf(address(this)));
	}

	/**
	 * @notice Approve bond worker as a spender for masterchef contract.
	 * @dev Everyone can make this call.
	 */
	function approveCakeTransfer() public {
		/**
		 * @dev Approve cake transfer
		 */
		Cake.approve(address(currentBondWorker), 2**256 - 1);
	}

	/**
	 * @notice Emergency unstake Cake to protect users funds.
	 * @dev Only owner can call.
	 */
	function emergencyUnstake() external onlyOwner {
		currentBondWorker.withdraw();
	}

	/**
	 * @notice Activate next bond to make sure bond data is valid before functioning.
	 * @dev This is external method, can be call by anyone.
	 */
	function activateNextBond() external whenCanActivate {
		/**
		 * @dev Expected next bond index.
		 */
		uint256 nextBondRound = currentBondRound.add(1);

		/**
		 * @dev Ensure the bond is not initialized before activating it.
		 */
		require(
			!bondPolicy[nextBondRound].BOND_CONFIG_INITIALIZED,
			"Error: previous round must not be initialized."
		);

		/**
		 * @dev Auto initialize next bond if the next bond index isn't initialized
		 */
		_configureBondPolicy(
			nextBondRound,
			bondPolicy[currentBondRound].BOND_DURATION,
			bondPolicy[currentBondRound].BOND_WAITING_TIME,
			block.timestamp.add(bondPolicy[currentBondRound].BOND_WAITING_TIME),
			block.timestamp.add(
				bondPolicy[currentBondRound].BOND_WAITING_TIME.mul(2)
			)
		);

		/**
		 * @dev Increase next bond index
		 */
		currentBondRound = nextBondRound;
	}

	/**
	 * @notice Deposit native Cake and receive back BondCake which is 1:1 ratio backed.
	 * @param depositedAmount {uint256} - the amount user wants to deposit and receive the same amount in BondCake.
	 */
	function depositCake(uint256 depositedAmount)
		external
		payable
		nonReentrant
		whenNotPaused
		whenBondInitialized
		whenCanDepositAndWithdraw
		needToCollectServiceFee
	{
		/**
		 * @dev Record bond ledger with current sender.
		 */
		address sender = msg.sender;

		/**
		 * @dev Transfer Cake to the pool.
		 */
		Cake.transferFrom(msg.sender, address(this), depositedAmount);

		/**
		 * @dev Mint CakeBond.
		 */
		_mint(msg.sender, depositedAmount);

		/**
		 * @dev Emit event
		 */
		emit DepositedCake(sender, currentBondRound, depositedAmount);
	}

	/**
	 * @notice Withdraw Cake from Syrup Cake pool.
	 * @dev Everyone can call withdraw cake.
	 * @param withdrawalAmount {uint256} - the amount user wants to deposit and receive the same amount in Cake.
	 */
	function withdrawCake(uint256 withdrawalAmount)
		external
		nonReentrant
		whenNotPaused
		whenBondInitialized
		whenCanDepositAndWithdraw
	{
		/**
		 * @dev Declare actor
		 */
		address actor = msg.sender;

		/**
		 * @dev Burning BCAKE
		 */
		burnFrom(actor, withdrawalAmount);

		/**
		 * @dev Transfer native Cake with appropriate exchange rate.
		 */
		Cake.transfer(actor, withdrawalAmount);

		/**
		 * @dev Emit event
		 */
		emit WithdrewCake(actor, currentBondRound, withdrawalAmount);
	}

	/**
	 * @notice Everyone can trigger staking.
	 * @dev If the locking phase for short term bond is passed, start staking. Everyone can call stake cake.
	 */
	function stakeCake()
		external
		nonReentrant
		whenNotPaused
		whenBondInitialized
		whenCanStake
	{
		/**
		 * @dev Calculate total bond.
		 */
		uint256 totalStakedAmount = Cake.balanceOf(address(this));

		/**
		 * @dev Deposit to CakePool.
		 */
		currentBondWorker.deposit(
			totalStakedAmount,
			bondPolicy[currentBondRound].BOND_DURATION
		);

		/**
		 * @dev Update actual bond start.
		 */
		bondPolicy[currentBondRound].ACTUAL_STAKE_START = block.timestamp;

		/**
		 * @dev Emit event
		 */
		emit StakedCake(msg.sender, currentBondRound, totalStakedAmount);
	}

	/*
	 * @notice Claim Cake payouts from Cake pool.
	 * @dev Everyone can call cake unstake. No need to bound in `whenNotPaused` modifier in case of emergency.
	 */
	function unstakeCake()
		external
		nonReentrant
		whenBondInitialized
		whenCanUnstake
	{
		/**
		 * @dev Start asking withdrawing native cake with bond worker.
		 */
		uint256 totalUnstakeAmount = currentBondWorker.withdraw();

		/**
		 * @dev Re-calculate exchange rate and finalize the current bond round.
		 */
		exchangeRate = _calculateExchangeRate();
		bondPolicy[currentBondRound].BOND_UNSTAKED = true;

		/**
		 * @dev Emit event
		 */
		emit UnstakedCake(msg.sender, currentBondRound, totalUnstakeAmount);
	}

	/*
	 * @notice Exchange BondCake with native Cake including payouts after compounding stake.
	 * @dev Everyone can call exchange bond.
	 */
	function exchangeBond(uint256 amount)
		external
		payable
		nonReentrant
		whenNotPaused
		whenBondInitialized
		whenCanExchange
		needToCollectServiceFee
	{
		/**
		 * @dev Declare actor
		 */
		address actor = msg.sender;

		/**
		 * @dev Burning BCAKE
		 */
		burnFrom(actor, amount);

		/**
		 * @dev Transfer native Cake with appropriate exchange rate.
		 */
		uint256 payout = amount.mul(exchangeRate).div(PRECISION);
		Cake.transfer(actor, payout);

		/*
		 * @dev Emit event
		 */
		emit ExchangedBond(actor, currentBondRound, payout);
	}
}
