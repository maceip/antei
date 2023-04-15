// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@oz/token/ERC20/IERC20.sol";
import "@oz/interfaces/IERC721Receiver.sol";
import "@oz/access/Ownable.sol";
import "@oz/security/ReentrancyGuard.sol";
import "@oz/token/ERC20/utils/SafeERC20.sol";
import "./IVoter.sol";
import "./IVotingEscrow.sol";
import "./IRewardsDistributor.sol";

contract VelocityVelodrome is IERC721Receiver, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable vctVeloToken;
    IERC20 public immutable VELO;

    IVoter public immutable voter;
    IVotingEscrow public immutable votingEscrow;
    IRewardsDistributor public immutable rewardsDistributor;

    uint256[] public veNFTIds;

    event RemoveExcessTokens(address token, address to, uint256 amount);
    event GenerateVeNFT(uint256 id, uint256 lockedAmount, uint256 lockDuration);
    event RelockVeNFT(uint256 id, uint256 lockDuration);
    event NFTVoted(uint256 id, uint256 timestamp);
    event WithdrawVeNFT(uint256 id, uint256 timestamp);
    event ClaimedBribes(uint256 id, uint256 timestamp);
    event ClaimedFees(uint256 id, uint256 timestamp);
    event ClaimedRebases(uint256[] id, uint256 timestamp);

    constructor(
        address _VctVeloAddress,
        address _VeloAddress,
        address _VoterAddress,
        address _VotingEscrowAddress,
        address _RewardsDistributorAddress
    ) {
        vctVeloToken = IERC20(_VctVeloAddress);
        VELO = IERC20(_VeloAddress);
        voter = IVoter(_VoterAddress);
        votingEscrow = IVotingEscrow(_VotingEscrowAddress);
        rewardsDistributor = IRewardsDistributor(_RewardsDistributorAddress);
    }

    function supportsInterface(bytes4 interfaceId)
        external
        pure
        returns (bool)
    {
        return
            interfaceId == type(IERC20).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == 0x01ffc9a7;
    }

    function lockVELO(uint256 _tokenAmount) external nonReentrant {
        uint256 _lockDuration = 365 days * 4;

        VELO.safeTransferFrom(msg.sender, address(this), _tokenAmount);
        vctVeloToken.safeTransferFrom(address(this), msg.sender, _tokenAmount);
        uint256 NFTId = votingEscrow.create_lock(_tokenAmount, _lockDuration);
        veNFTIds.push(NFTId);
        uint256 weeksLocked = (_lockDuration / 1 weeks) * 1 weeks;

        emit GenerateVeNFT(NFTId, _tokenAmount, weeksLocked);
    }

    function relockVELO(uint256 _NFTId, uint256 _lockDuration)
        external
        onlyOwner
    {
        votingEscrow.increase_unlock_time(_NFTId, _lockDuration);
        uint256 weeksLocked = (_lockDuration / 1 weeks) * 1 weeks;
        emit RelockVeNFT(_NFTId, weeksLocked);
    }

    function vote(
        uint256[] calldata _NFTIds,
        address[] calldata _poolVote,
        uint256[] calldata _weights
    ) external onlyOwner {
        uint256 length = _NFTIds.length;
        for (uint256 i = 0; i < length; ++i) {
            voter.vote(_NFTIds[i], _poolVote, _weights);
            emit NFTVoted(_NFTIds[i], block.timestamp);
        }
    }

    function withdrawNFT(uint256 _tokenId, uint256 _index) external onlyOwner {
        //ensure we are deleting the right veNFTId slot
        require(veNFTIds[_index] == _tokenId, "Wrong index slot");
        //abstain from current epoch vote to reset voted to false, allowing withdrawal
        voter.reset(_tokenId);
        //request withdrawal
        votingEscrow.withdraw(_tokenId);
        //delete stale veNFTId as veNFT is now burned.
        delete veNFTIds[_index];
        emit WithdrawVeNFT(_tokenId, block.timestamp);
    }

    function removeERC20Tokens(
        address[] calldata _tokens,
        uint256[] calldata _amounts
    ) external onlyOwner {
        uint256 length = _tokens.length;
        require(length == _amounts.length, "Mismatched arrays");

        for (uint256 i = 0; i < length; ++i) {
            IERC20(_tokens[i]).safeTransfer(msg.sender, _amounts[i]);
            emit RemoveExcessTokens(_tokens[i], msg.sender, _amounts[i]);
        }
    }

    function transferNFTs(
        uint256[] calldata _tokenIds,
        uint256[] calldata _indexes
    ) external onlyOwner {
        uint256 length = _tokenIds.length;
        require(length == _indexes.length, "Mismatched arrays");

        for (uint256 i = 0; i < length; ++i) {
            require(veNFTIds[_indexes[i]] == _tokenIds[i], "Wrong index slot");
            delete veNFTIds[_indexes[i]];
            //abstain from current epoch vote to reset voted to false, allowing transfer
            voter.reset(_tokenIds[i]);
            //here msg.sender is always owner.
            votingEscrow.safeTransferFrom(
                address(this),
                msg.sender,
                _tokenIds[i]
            );
            //no event needed as votingEscrow emits one on transfer anyway
        }
    }

    function claimBribesMultiNFTs(
        address[] calldata _bribes,
        address[][] calldata _tokens,
        uint256[] calldata _tokenIds
    ) external nonReentrant {
        uint256 length = _tokenIds.length;
        for (uint256 i = 0; i < length; ++i) {
            voter.claimBribes(_bribes, _tokens, _tokenIds[i]);
            emit ClaimedBribes(_tokenIds[i], block.timestamp);
        }
    }

    function claimFeesMultiNFTs(
        address[] calldata _fees,
        address[][] calldata _tokens,
        uint256[] calldata _tokenIds
    ) external nonReentrant {
        uint256 length = _tokenIds.length;
        for (uint256 i = 0; i < length; ++i) {
            voter.claimFees(_fees, _tokens, _tokenIds[i]);
            emit ClaimedFees(_tokenIds[i], block.timestamp);
        }
    }

    function claimRebaseMultiNFTs(uint256[] calldata _tokenIds)
        external
        nonReentrant
    {
        //claim_many always returns true unless a tokenId = 0 so return bool is not needed
        //slither-disable-next-line unused-return
        rewardsDistributor.claim_many(_tokenIds);
        emit ClaimedRebases(_tokenIds, block.timestamp);
    }

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _id,
        bytes calldata _data
    ) public virtual override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
