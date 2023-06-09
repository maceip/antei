// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@oz/token/ERC721/IERC721.sol";
import "@oz/token/ERC20/IERC20.sol";
import "@prb-math/PRBMathSD59x18.sol";

contract Auction {
    event Init(uint256 blockStart);
    event Swap(address indexed buyer, uint256 amountBuy, uint256 amountSell);
    event Withdraw(uint256 amount);

    error AlreadyStarted();
    error Inactive();
    error Unauthorized();

    using PRBMathSD59x18 for int256;

    address public owner;

    uint256 public blockStart;

    address public tokenBase;
    address public tokenQuote;
    uint256 public amountBase;
    uint256 public initialPrice;
    uint256 public halvingPeriod;
    uint256 public swapPeriod;
    uint256 public tokenId;

    modifier whenInactive() {
        if (blockStart > 0) {
            revert AlreadyStarted();
        }
        _;
    }

    modifier whenActive() {
        if (blockStart == 0) {
            revert Inactive();
        }
        _;
    }

    modifier onlyOwner() {
        if (owner != msg.sender) {
            revert Unauthorized();
        }
        _;
    }

    constructor(
        address _owner,
        address _tokenBase,
        address _tokenQuote,
        uint256 _amountBase,
        uint256 _initialPrice,
        uint256 _halvingPeriod,
        uint256 _swapPeriod,
        uint256 _tokenID
    ) {
        owner = _owner;
        tokenBase = _tokenBase;
        tokenQuote = _tokenQuote;
        amountBase = _amountBase;
        initialPrice = _initialPrice;
        halvingPeriod = _halvingPeriod;
        swapPeriod = _swapPeriod;
        tokenId = _tokenID;
    }

    function init() external onlyOwner whenInactive {
        IERC721(tokenBase).safeTransferFrom(msg.sender, address(this), tokenId);
        blockStart = block.number;
        emit Init(blockStart);
    }

    function getPrice(uint256 amountIn)
        public
        view
        whenActive
        returns (uint256 amountOut)
    {
        uint256 boughtAmount = amountBase -
            IERC721(tokenBase).balanceOf(address(this)) +
            amountIn;
        int256 exponent = ((int256(block.number) - int256(blockStart)) *
            1 ether -
            ((int256(boughtAmount) * 1 ether) / int256(amountBase)) *
            int256(swapPeriod)) / int256(halvingPeriod);
        amountOut = uint256((int256(initialPrice) * 1 ether) / exponent.exp2());
    }

    function buy(uint256 amountBuy)
        external
        whenActive
        returns (uint256 amountSell)
    {
        uint256 price = getPrice(amountBuy);
        amountSell = (price * amountBuy) / 1 ether;
        IERC20(tokenQuote).transferFrom(msg.sender, address(this), amountSell);
        IERC721(tokenBase).safeTransferFrom(address(this), msg.sender, tokenId);
        emit Swap(msg.sender, amountBuy, amountSell);
    }

    function withdraw() external onlyOwner returns (uint256 amount) {
        amount = IERC20(tokenQuote).balanceOf(address(this));
        IERC20(tokenQuote).transfer(msg.sender, amount);
        emit Withdraw(amount);
    }
}
