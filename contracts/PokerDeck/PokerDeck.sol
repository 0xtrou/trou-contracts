// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./Helper.sol";

contract PokerDeck is ERC721Enumerable, ReentrancyGuard, Ownable {
	using SafeMath for uint256;

	struct MetaInfo {
		string card1;
		string card2;
		string card3;
		string card4;
		string card5;
		address signedBy;
	}

	mapping(uint256 => MetaInfo) public metaInfo;
	address payable public taxPool;

	uint256 public mintFee = 50 ether;
	string[] private cards = [
		unicode"🂠",
		unicode"🂡",
		unicode"🂢",
		unicode"🂣",
		unicode"🂤",
		unicode"🂥",
		unicode"🂦",
		unicode"🂧",
		unicode"🂨",
		unicode"🂩",
		unicode"🂪",
		unicode"🂫",
		unicode"🂭",
		unicode"🂱",
		unicode"🂲",
		unicode"🂳",
		unicode"🂴",
		unicode"🂵",
		unicode"🂶",
		unicode"🂷",
		unicode"🂸",
		unicode"🂹",
		unicode"🂺",
		unicode"🂻",
		unicode"🂽",
		unicode"🂾",
		unicode"🃁",
		unicode"🃂",
		unicode"🃃",
		unicode"🃄",
		unicode"🃅",
		unicode"🃆",
		unicode"🃇",
		unicode"🃈",
		unicode"🃉",
		unicode"🃊",
		unicode"🃋",
		unicode"🃍",
		unicode"🃎",
		unicode"🃑",
		unicode"🃒",
		unicode"🃓",
		unicode"🃔",
		unicode"🃕",
		unicode"🃖",
		unicode"🃗",
		unicode"🃘",
		unicode"🃙",
		unicode"🃚",
		unicode"🃛",
		unicode"🃝",
		unicode"🃞",
		unicode"🃟"
	];

	function pluck(
		uint256 tokenId,
		string memory keyPrefix,
		string[] memory sourceArray
	) internal view returns (string memory) {
		uint256 rand = Helper.random(
			string(
				abi.encodePacked(
					keyPrefix,
					Helper.toString(tokenId),
					metaInfo[tokenId].signedBy,
					block.timestamp,
					gasleft()
				)
			)
		);
		string memory output = sourceArray[rand % sourceArray.length];
		return output;
	}

	function getCard(uint256 tokenId, string memory cardPosition)
		public
		view
		returns (string memory)
	{
		string memory card = pluck(tokenId, cardPosition, cards);

		if (
			!Helper.compareStrings(card, metaInfo[tokenId].card1) &&
			!Helper.compareStrings(card, metaInfo[tokenId].card2) &&
			!Helper.compareStrings(card, metaInfo[tokenId].card3) &&
			!Helper.compareStrings(card, metaInfo[tokenId].card4) &&
			!Helper.compareStrings(card, metaInfo[tokenId].card5)
		) {
			return card;
		}

		return pluck(tokenId, cardPosition, cards);
	}

	function getAttributes(uint256 tokenId)
		private
		view
		returns (string memory)
	{
		return
			string(
				abi.encodePacked(
					string(
						abi.encodePacked(
							',"attributes": [',
							'{"trait_type": "Left Edge Card", "value":"',
							metaInfo[tokenId].card1,
							'"},',
							'{"trait_type": "Left Card", "value":"',
							metaInfo[tokenId].card2,
							'"},'
						)
					),
					string(
						abi.encodePacked(
							'{"trait_type": "Middle Card", "value":"',
							metaInfo[tokenId].card3,
							'"},',
							'{"trait_type": "Right Card", "value":"',
							metaInfo[tokenId].card4,
							'"},',
							'{"trait_type": "Right Edge Card", "value":"',
							metaInfo[tokenId].card5,
							'"},'
						)
					),
					string(
						abi.encodePacked(
							'{"trait_type": "Signed By", "value":"',
							Helper.addressToString(metaInfo[tokenId].signedBy),
							'"}',
							"]"
						)
					)
				)
			);
	}

	function tokenURI(uint256 tokenId)
		public
		view
		override
		returns (string memory)
	{
		string[11] memory parts;
		parts[
			0
		] = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 70px; }</style><rect width="100%" height="100%" fill="black" /><text x="10" y="165" class="base">';

		parts[1] = metaInfo[tokenId].card1;

		parts[2] = '</text><text x="80" y="165" class="base">';

		parts[3] = metaInfo[tokenId].card2;

		parts[4] = '</text><text x="150" y="165" class="base">';

		parts[5] = metaInfo[tokenId].card3;

		parts[6] = '</text><text x="220" y="165" class="base">';

		parts[7] = metaInfo[tokenId].card4;

		parts[8] = '</text><text x="290" y="165" class="base">';

		parts[9] = metaInfo[tokenId].card5;

		parts[10] = string(
			abi.encodePacked(
				'</text><text class="base" y="300" style="font-size: 12px;font-family: serif;" x="95">',
				unicode"©",
				" PokerDeck. All rights reserved.</text></svg>"
			)
		);

		string memory output = string(
			abi.encodePacked(
				parts[0],
				parts[1],
				parts[2],
				parts[3],
				parts[4],
				parts[5],
				parts[6],
				parts[7],
				parts[8]
			)
		);
		output = string(abi.encodePacked(output, parts[9], parts[10]));

		string memory json = Helper.encode(
			bytes(
				string(
					abi.encodePacked(
						'{"name": "Deck #',
						Helper.toString(tokenId),
						'", "description": "PokerDeck (Deck) is the first algorithm-generated NFTs that was built on blockchain. The NFT art is inspired by a poker nut hand, and sometimes the feeling playing poker is similar to the feeling venturing to the blockchain world. This NFT was signed by ',
						Helper.addressToString(metaInfo[tokenId].signedBy),
						'.", "image": "data:image/svg+xml;base64,',
						Helper.encode(bytes(output)),
						'"',
						getAttributes(tokenId),
						"}"
					)
				)
			)
		);
		output = string(
			abi.encodePacked("data:application/json;base64,", json)
		);

		return output;
	}

	function _mintPoker(address minter, uint256 tokenId) private {
		_safeMint(minter, tokenId);

		// permanently update
		metaInfo[tokenId].card1 = getCard(tokenId, "card1");
		metaInfo[tokenId].card2 = getCard(tokenId, "card2");
		metaInfo[tokenId].card3 = getCard(tokenId, "card3");
		metaInfo[tokenId].card4 = getCard(tokenId, "card4");
		metaInfo[tokenId].card5 = getCard(tokenId, "card5");
		metaInfo[tokenId].signedBy = msg.sender;
	}

	function mint() public payable nonReentrant {
		require(msg.value == mintFee, "Error: below mint fee");

		(bool isSentToTaxPool, ) = taxPool.call{value: address(this).balance}(
			""
		);

		require(isSentToTaxPool, "Error: cannot send payout to tax pool");

		uint256 tokenId = totalSupply();

		require(
			tokenId <= 8888,
			"Error: supply for buy is limited at 8,889 PokerDeck"
		);

		_mintPoker(msg.sender, tokenId);
	}

	constructor() ERC721("PokerDeck", "Deck") Ownable() {
		taxPool = payable(owner());
	}
}
