// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IVotingEscrow {
    struct Point {
        int128 bias;
        int128 slope; // # -dweight / dt
        uint256 ts;
        uint256 blk; // block
    }

    function token() external view returns (address);

    function team() external returns (address);

    function epoch() external view returns (uint256);

    function point_history(uint256 loc) external view returns (Point memory);

    function user_point_history(uint256 tokenId, uint256 loc)
        external
        view
        returns (Point memory);

    function user_point_epoch(uint256 tokenId) external view returns (uint256);

    function ownerOf(uint256) external view returns (address);

    function isApprovedOrOwner(address, uint256) external view returns (bool);

    function transferFrom(
        address,
        address,
        uint256
    ) external;

    function voting(uint256 tokenId) external;

    function abstain(uint256 tokenId) external;

    function attach(uint256 tokenId) external;

    function detach(uint256 tokenId) external;

    function checkpoint() external;

    function deposit_for(uint256 tokenId, uint256 value) external;

    function create_lock_for(
        uint256,
        uint256,
        address
    ) external returns (uint256);

    function create_lock(uint256 _value, uint256 _lock_duration)
        external
        returns (uint256);

    function increase_unlock_time(uint256 tokenId, uint256 lock_duration)
        external;

    function balanceOfNFT(uint256) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function withdraw(uint256 _tokenId) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}
