// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IVoter {
    function _ve() external view returns (address);

    function governor() external view returns (address);

    function emergencyCouncil() external view returns (address);

    function attachTokenToGauge(uint256 _tokenId, address account) external;

    function detachTokenFromGauge(uint256 _tokenId, address account) external;

    function emitDeposit(
        uint256 _tokenId,
        address account,
        uint256 amount
    ) external;

    function emitWithdraw(
        uint256 _tokenId,
        address account,
        uint256 amount
    ) external;

    function isWhitelisted(address token) external view returns (bool);

    function notifyRewardAmount(uint256 amount) external;

    function distribute(address _gauge) external;

    function vote(
        uint256 tokenId,
        address[] calldata _poolVote,
        uint256[] calldata _weights
    ) external;

    function claimBribes(
        address[] memory _bribes,
        address[][] memory _tokens,
        uint256 _tokenId
    ) external;

    function claimFees(
        address[] memory _fees,
        address[][] memory _tokens,
        uint256 _tokenId
    ) external;

    function reset(uint256 _tokenId) external;

    function gauges(address pool) external view returns (address);
}
