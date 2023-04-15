pragma solidity 0.8.19;

import {Test} from "@std/Test.sol";
import {PRBTest} from "@prb/test/PRBTest.sol";
import "@std/console.sol";
import {VctVelo} from "../VctVelo.sol";
import {VelocityVelodrome} from "../VelocityVelodrome.sol";
import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";
import {MockERC721} from "@solmate/test/utils/mocks/MockERC721.sol";
import "@mock/MockProvider.sol";
import "../IVoter.sol";
import "../IRewardsDistributor.sol";

contract DeployerTest is Test {
    MockProvider provider = new MockProvider();
    IVoter voter = IVoter(address(provider));
    IRewardsDistributor rewards = IRewardsDistributor(address(provider));
    VctVelo vctVelo;
    MockERC20 VELO;
    MockERC721 VENFT;

    VelocityVelodrome velocityVelodrome;

    /*address _VctVeloAddress,
        address _VeloAddress,
        address _VoterAddress,
        address _VotingEscrowAddress,
        address _RewardsDistributorAddress
        */

    function setUp() public {
        vctVelo = new VctVelo();
        VELO = new MockERC20("VELO", "VELO", 18);
        VENFT = new MockERC721("VENFT", "VENFT");
        velocityVelodrome = new VelocityVelodrome(
            address(vctVelo),
            address(VELO),
            address(voter),
            address(VENFT),
            address(rewards)
        );
    }
}
