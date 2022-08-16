/// [MIT License]
/// @title Helper
/// @notice Provides helpers
/// @author PokerDeck @ pokerDeck@appchain.cloud
library Helper {
	bytes internal constant TABLE =
		"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

	function random(string memory input) external pure returns (uint256) {
		return uint256(keccak256(abi.encodePacked(input)));
	}

	function addressToString(address _addr)
		external
		pure
		returns (string memory)
	{
		bytes32 value = bytes32(uint256(uint160(_addr)));
		bytes memory alphabet = "0123456789abcdef";

		bytes memory str = new bytes(42);
		str[0] = "0";
		str[1] = "x";
		for (uint256 i = 0; i < 20; i++) {
			str[2 + i * 2] = alphabet[uint256(uint8(value[i + 12] >> 4))];
			str[3 + i * 2] = alphabet[uint256(uint8(value[i + 12] & 0x0f))];
		}
		return string(str);
	}

	function compareStrings(string memory a, string memory b)
		external
		pure
		returns (bool)
	{
		return (keccak256(abi.encodePacked((a))) ==
			keccak256(abi.encodePacked((b))));
	}

	function toString(uint256 value) external pure returns (string memory) {
		// Inspired by OraclizeAPI's implementation - MIT license
		// https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

		if (value == 0) {
			return "0";
		}
		uint256 temp = value;
		uint256 digits;
		while (temp != 0) {
			digits++;
			temp /= 10;
		}
		bytes memory buffer = new bytes(digits);
		while (value != 0) {
			digits -= 1;
			buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
			value /= 10;
		}
		return string(buffer);
	}

	/// @notice Encodes some bytes to the base64 representation
	function encode(bytes memory data) external pure returns (string memory) {
		uint256 len = data.length;
		if (len == 0) return "";

		// multiply by 4/3 rounded up
		uint256 encodedLen = 4 * ((len + 2) / 3);

		// Add some extra buffer at the end
		bytes memory result = new bytes(encodedLen + 32);

		bytes memory table = TABLE;

		assembly {
			let tablePtr := add(table, 1)
			let resultPtr := add(result, 32)

			for {
				let i := 0
			} lt(i, len) {

			} {
				i := add(i, 3)
				let input := and(mload(add(data, i)), 0xffffff)

				let out := mload(add(tablePtr, and(shr(18, input), 0x3F)))
				out := shl(8, out)
				out := add(
					out,
					and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF)
				)
				out := shl(8, out)
				out := add(
					out,
					and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF)
				)
				out := shl(8, out)
				out := add(
					out,
					and(mload(add(tablePtr, and(input, 0x3F))), 0xFF)
				)
				out := shl(224, out)

				mstore(resultPtr, out)

				resultPtr := add(resultPtr, 4)
			}

			switch mod(len, 3)
			case 1 {
				mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
			}
			case 2 {
				mstore(sub(resultPtr, 1), shl(248, 0x3d))
			}

			mstore(result, encodedLen)
		}

		return string(result);
	}
}
