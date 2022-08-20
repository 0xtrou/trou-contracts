pragma solidity >=0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./ICakePool.sol";

/*
 * @dev BondWorker smart contract.
 */
contract BondWorker is Ownable, ReentrancyGuard {
	/**
	 * @notice Enable SafeMath for uint256
	 */
	using SafeMath for uint256;

	/*
	 * @notice Binding Cake address.
	 */
	IERC20 public Cake;

	/**
	 * @notice Binding Cake compound staking pool address.
	 */
	ICakePool public CompoundCakePool;

	/**
	 * @notice MasterChef address.
	 */
	address public masterChef;

	/**
	 * @notice Initialize contract with native Cake address and CakePool address.
	 */
	constructor(address nativeCakeAddress, address cakePoolAddress) {
		/**
		 * @dev Binding Cake address.
		 */
		Cake = IERC20(nativeCakeAddress);

		/**
		 * @dev Binding CakePool address.
		 */
		CompoundCakePool = ICakePool(cakePoolAddress);

		/**
		 * @dev Binding MasterChef address.
		 */
		masterChef = owner();

		/*
		 * @dev Approve Cake transfer.
		 */
		approveCakeTransfer();
	}

	/**
	 * @notice Allow publicly approving transfer for native Cake token.
	 */
	function approveCakeTransfer() public {
		/**
		 * @dev Approve CompoundCakePool to transfer Cake to the pool in the deposit func.
		 */
		bool result = Cake.approve(address(CompoundCakePool), 2**256 - 1);
		require(
			result,
			"Error: Cannot approve Cake transfer for CompoundCakePool"
		);
	}

	/**
	 * @notice Deposit native Cake.
	 * @param depositedAmount {uint256} - the amount user wants to deposit.
	 * @param lockDuration {uint256} - the lock duration in seconds.
	 */
	function deposit(uint256 depositedAmount, uint256 lockDuration)
		external
		onlyOwner
	{
		/**
		 * @dev Transfer Cake from MasterChef to this.
		 */
		Cake.transferFrom(masterChef, address(this), depositedAmount);

		/**
		 * @dev Deposit to CakePool
		 */
		CompoundCakePool.deposit(depositedAmount, lockDuration);
	}

	/*
	 * @notice Withdraw native CAKE.
	 */
	function withdraw() external onlyOwner returns (uint256) {
		/**
		 * @dev Calculate balance before withdrawing Cake.
		 */
		uint256 beforeBalance = Cake.balanceOf(address(this));

		/**
		 * @dev Withdraw 100% Cake from CakePool.
		 */
		CompoundCakePool.withdraw(100);

		/**
		 * @dev Calculate balance after withdrawing Cake.
		 */
		uint256 afterBalance = Cake.balanceOf(address(this));

		/**
		 * @dev Calculate total payouts and return to MasterChef.
		 */
		uint256 totalPayouts = afterBalance.sub(beforeBalance);

		/**
		 * @dev Transfer Cake back to masterChef.
		 */
		Cake.transfer(masterChef, totalPayouts);

		/**
		 * @dev Return payouts amount.
		 */
		return totalPayouts;
	}
}
