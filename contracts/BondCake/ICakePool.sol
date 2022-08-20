interface ICakePool {
	/**
	 * @notice Deposit funds into the Cake Pool.
	 * @dev Only possible when contract not paused.
	 * @param _amount: number of tokens to deposit (in CAKE)
	 * @param _lockDuration: Token lock duration
	 */
	function deposit(uint256 _amount, uint256 _lockDuration) external;

	/**
	 * @notice Withdraw funds from the Cake Pool.
	 * @param _shares: Number of shares to withdraw
	 */
	function withdraw(uint256 _shares) external;
}
