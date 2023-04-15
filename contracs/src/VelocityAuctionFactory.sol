// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./VelocityAuction.sol";

contract VelocityAuctionFactory {
    event NewAuction(
        address auction,
        address indexed owner,
        address indexed tokenBase,
        address indexed tokenQuote,
        uint256 tokenId,
        uint256 amountBase,
        uint256 initialPrice,
        uint256 halvingPeriod,
        uint256 swapPeriod
    );

    function createAuction(
        address tokenBase,
        address tokenQuote,
        uint256 tokenId,
        uint256 amountBase,
        uint256 initialPrice,
        uint256 halvingPeriod,
        uint256 swapPeriod
    ) external returns (address auction) {
        require(tokenBase != tokenQuote);
        auction = address(
            new Auction(
                msg.sender,
                tokenBase,
                tokenQuote,
                amountBase,
                initialPrice,
                halvingPeriod,
                swapPeriod,
                tokenId
            )
        );
        emit NewAuction(
            address(auction),
            msg.sender,
            tokenBase,
            tokenQuote,
            amountBase,
            initialPrice,
            halvingPeriod,
            swapPeriod,
            tokenId
        );
    }
}
