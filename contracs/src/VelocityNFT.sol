// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@oz/token/ERC20/IERC20.sol";
import {SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";
import {ERC721} from "@oz/token/ERC721/ERC721.sol";
import {IERC721} from "@oz/token/ERC721/IERC721.sol";
import {ERC721Holder} from "@oz/token/ERC721/utils/ERC721Holder.sol";
import {ERC1155Receiver} from "@oz/token/ERC1155/utils/ERC1155Receiver.sol";
import {ERC1155} from "@oz/token/ERC1155/ERC1155.sol";
import {IERC1155} from "@oz/token/ERC1155/IERC1155.sol";
import {ERC1155Holder} from "@oz/token/ERC1155/utils/ERC1155Holder.sol";
import {Strings} from "@oz/utils/Strings.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {IVelocityNFT} from "./IVelocityNFT.sol";

/**
 * @title VelocityNFT
 * @author mac
 * @notice This contract is based on the EIP-3589: https://eips.ethereum.org/EIPS/eip-3589
 */
contract VelocityNFT is
    ERC721,
    ERC721Holder,
    ERC1155Holder,
    IVelocityNFT,
    Ownable
{
    using SafeERC20 for IERC20;
    using Strings for uint256;

    uint256 private nonce;
    string private _baseURIextended;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory baseURIextended
    ) ERC721(_name, _symbol) {
        _baseURIextended = baseURIextended;
    }

    /**
     * @dev Transfers all assets to the escrow contract and mints an ERC721 NFT with a hash as its token ID.
     * @param to The address to which the NFT will be minted.
     * @param addresses An array of contract addresses for all the assets being sent to the escrow contract.
     * @param numbers An array of numbers, amounts, and IDs for every asset sent to the escrow contract.
     * @return tokenId The token ID of the minted NFT.
     */
    function safeMint(
        address to,
        address[] calldata addresses,
        uint256[] memory numbers
    ) public override returns (uint256 tokenId) {
        require(to != address(0), "VelocityNFT: Zero address");
        require(
            addresses.length == numbers[1] + numbers[2] + numbers[3],
            "VelocityNFT: Arrays don't match"
        );
        require(
            addresses.length == numbers.length - 4 - numbers[3],
            "VelocityNFT: Arrays don't match"
        );
        uint256 pointerA; //points to first erc20 address, if any
        uint256 pointerB = 4; //points to first erc20 amount, if any
        for (uint256 i = 0; i < numbers[1]; i++) {
            require(numbers[pointerB] > 0, "VelocityNFT: Amount is 0");
            IERC20 token = IERC20(addresses[pointerA++]);
            uint256 orgBalance = token.balanceOf(address(this));
            token.safeTransferFrom(
                _msgSender(),
                address(this),
                numbers[pointerB]
            );
            numbers[pointerB++] = token.balanceOf(address(this)) - orgBalance;
        }

        uint256 ERC721Length = numbers[2];
        for (uint256 j = 0; j < ERC721Length; j++) {
            IERC721(addresses[pointerA++]).safeTransferFrom(
                _msgSender(),
                address(this),
                numbers[pointerB++]
            );
        }

        uint256 ERC1155Length = numbers[3];
        for (uint256 k = 0; k < ERC1155Length; k++) {
            IERC1155(addresses[pointerA++]).safeTransferFrom(
                _msgSender(),
                address(this),
                numbers[pointerB],
                numbers[ERC1155Length + pointerB++],
                ""
            );
        }
        tokenId = this.hash(nonce, addresses, numbers);
        super._mint(to, tokenId);
        emit VelocityAsset(to, tokenId, nonce, addresses, numbers);
        nonce++;
    }

    /**
     * @dev Burns a previously emitted NFT to claim all the associated assets from the escrow contract.
     * @param to The recipient of the assets being claimed.
     * @param tokenId The hash of all associated assets.
     * @param salt The nonce, emitted in the VelocityAsset event.
     * @param addresses An array containing the contract addresses of every asset sent to the escrow contract.
     * Emitted in the VelocityAsset event.
     * @param numbers An array containing numbers, amounts and IDs for every asset sent to the escrow contract.
     * Emitted in the VelocityAsset event.
     */
    function burn(
        address to,
        uint256 tokenId,
        uint256 salt,
        address[] calldata addresses,
        uint256[] calldata numbers
    ) public override {
        require(
            _msgSender() == ownerOf(tokenId),
            "VelocityNFT: Token not owned"
        );
        require(
            tokenId == this.hash(salt, addresses, numbers),
            "VelocityNFT: Wrong token hash"
        );
        super._burn(tokenId);
        payable(to).transfer(numbers[0]);
        uint256 pointerA; //points to first erc20 address, if any
        uint256 pointerB = 4; //points to first erc20 amount, if any
        for (uint256 i = 0; i < numbers[1]; i++) {
            require(numbers[pointerB] > 0, "VelocityNFT: Amount is 0");
            IERC20(addresses[pointerA++]).safeTransfer(to, numbers[pointerB++]);
        }
        for (uint256 j = 0; j < numbers[2]; j++) {
            IERC721(addresses[pointerA++]).safeTransferFrom(
                address(this),
                to,
                numbers[pointerB++]
            );
        }
        for (uint256 k = 0; k < numbers[3]; k++) {
            IERC1155(addresses[pointerA++]).safeTransferFrom(
                address(this),
                to,
                numbers[pointerB],
                numbers[numbers[3] + pointerB++],
                ""
            );
        }
        emit VelocityAssetClaimed(tokenId, msg.sender, addresses, numbers);
    }

    /**
     * @dev Generates a hash of all assets sent to the escrow contract. This hash is used as the NFT token ID
     * and is the "key" to claim the assets back.
     * @param salt An index-like parameter that is incremented by one with each new NFT created to prevent collisions.
     * @param addresses An array containing all the contract addresses of every asset sent to the escrow contract.
     * The layout of the array is as follows: erc20 addresses, erc721 addresses, and erc1155 addresses.
     * @param numbers An array containing numbers, amounts, and IDs for every asset sent to the escrow contract.
     * The layout of the array is as follows: eth, erc20.length, erc721.length, erc1155.length, erc20 amounts,
     *  erc721 ids, erc1155 ids, and erc1155 amounts.
     * @return tokenId The NFT token ID, which is generated by hashing the inputs.
     */
    function hash(
        uint256 salt,
        address[] calldata addresses,
        uint256[] calldata numbers
    ) external pure override returns (uint256 tokenId) {
        bytes32 signature = keccak256(abi.encodePacked(salt));
        for (uint256 i = 0; i < addresses.length; i++) {
            signature = keccak256(abi.encodePacked(signature, addresses[i]));
        }
        for (uint256 j = 0; j < numbers.length; j++) {
            signature = keccak256(abi.encodePacked(signature, numbers[j]));
        }
        assembly {
            tokenId := signature
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC1155Receiver)
        returns (bool)
    {
        return
            ERC721.supportsInterface(interfaceId) ||
            ERC1155Receiver.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(tokenId), "VelocityNFT: Nonexistent token");
        return _baseURIextended;
    }
}
