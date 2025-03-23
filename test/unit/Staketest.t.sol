// SPDX-License-Identifer: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployStake} from "script/DeployStake.s.sol";
import {Stake} from "src/Stake.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/Mocks/LinkToken.sol";
import {CodeConstantVariable} from "script/HelperConfig.s.sol";

contract StakeTesting is CodeConstantVariable, Test {
    Stake public stake;
    HelperConfig public helperconfig;

    address public PLAYER = makeAddr("Player");
    uint256 public constant PLAYER_BALANCE_STARTING = 20 ether;
    uint256 public constant LINK_TOKEN_BALANCE = 200 ether;

    uint256 entryfee;
    uint256 interval;
    address vrfcoordinator;
    bytes32 gaslane;
    uint256 subId;
    uint32 callbackgaslimit;
    LinkToken link;

    event Stake_PlayerEntered(address indexed player);
    event Stake_WinnerListUpdated(address indexed Winners);

    function setUp() external {
        DeployStake deployer = new DeployStake();
        (stake, helperconfig) = deployer.run();

        vm.deal(PLAYER, PLAYER_BALANCE_STARTING);

        HelperConfig.NetworkConfig memory config = helperconfig.getConfig();
        entryfee = config.entryfee;
        interval = config.interval;
        vrfcoordinator = config.vrfcoordinator;
        gaslane = config.gaslane;
        subId = config.subId;
        callbackgaslimit = config.callbackgaslimit;
        link = LinkToken(config.link);

        vm.startPrank(msg.sender);
        if (block.chainid == LOCAL_CHAINID) {
            link.mint(msg.sender, LINK_TOKEN_BALANCE);
            VRFCoordinatorV2_5Mock(vrfcoordinator).fundSubscription(subId, LINK_TOKEN_BALANCE);
        }
        link.approve(vrfcoordinator, LINK_TOKEN_BALANCE);
        vm.stopPrank();
    }

    function testStakeConditionBeforeEverything() public view {
        assert(stake.getStakeCondition() == Stake.StakeCondition.OPEN);
    }

    function testWillrevertIFnotEnoughEntryfee() public {
        vm.prank(PLAYER);

        vm.expectRevert(Stake.Stake__Insufficient_Eth_Entryfee.selector);
        stake.StakeEntry();
    }

    function testStakewillRecordPlayersOnEntry() public {
        vm.prank(PLAYER);
        stake.StakeEntry{value: entryfee}();

        address playerRecorded = stake.getPlayersbyIndex(0);
        assert(playerRecorded == PLAYER);
    }

    function testEventEmitforEnterStake() public {
        // Arrange
        vm.prank(PLAYER);
        //act
        vm.expectEmit(true, false, false, false, address(stake));
        emit Stake_PlayerEntered(PLAYER);

        //assert
        stake.StakeEntry{value: entryfee}();
    }

    function testCannotEnterStakeIfInCalculatingCondition() public {
        //ARRANGE
        vm.prank(PLAYER);
        stake.StakeEntry{value: entryfee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        console.log("Balance: ", address(stake).balance);
        console.log("Players count: ", stake.getPlayers());
        console.log("Stake condition: ", uint256(stake.getStakeCondition()));

        console.log("Required interval: ", stake.getInterval());

        stake.performUpkeep("");
        console.log("Stake condition after performUpkeep: ", uint256(stake.getStakeCondition()));

        vm.expectRevert(Stake.Stake__EntryClosedAttheMoment.selector);
        vm.prank(PLAYER);
        stake.StakeEntry{value: entryfee}();
    }

    function testcheckUPkeepIfNoBlanceReturnsFalse() public {
        vm.warp(block.timestamp + interval);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = stake.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testcheckUPkeepiSFalseIfNotOpen() public {
        vm.prank(PLAYER);
        stake.StakeEntry{value: entryfee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        stake.performUpkeep("");

        (bool upkeepNeeded,) = stake.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testcheckUpkeepisFalseIfenoughTimeNotPassed() public {
        vm.prank(PLAYER);
        stake.StakeEntry{value: entryfee}();
        vm.warp(block.timestamp + interval - 1);
        (bool upkeepNeeded,) = stake.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testcheckUpkeedIsfalseIfNoPlayerhasJoined() public {
        (bool upkeedNeeded,) = stake.checkUpkeep("");
        assert(!upkeedNeeded);
    }

    function testcheckUpkeepReturnsTrueIfAllConditionsAreMet() public {
        vm.prank(PLAYER);
        stake.StakeEntry{value: entryfee}();
        vm.warp(block.timestamp + interval + 1);
        (bool upkeepNeeded,) = stake.checkUpkeep("");
        assert(upkeepNeeded);
    }

    //// PERFROM UPKEEP TEST ///

    modifier GetIntoStake() {
        //will msotly do the arrange part
        vm.prank(PLAYER);
        stake.StakeEntry{value: entryfee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeeponlyRunIfCHeckupkeepReturnsTrue() public GetIntoStake {
        //arrange
        /* the modifier GetIntoStake will do part */

        //Act //assert
        stake.performUpkeep("");
    }

    function testPerformUpkeepWillRevertIfCheckUpkeepIsFalse() public {
        //arrange
        uint256 currentBalance = 0;
        uint256 numOfPlayers = 0;
        Stake.StakeCondition sCondition = stake.getStakeCondition();

        vm.prank(PLAYER);
        stake.StakeEntry{value: entryfee}();
        currentBalance = currentBalance + entryfee;
        numOfPlayers = 1;

        //act //assert

        vm.expectRevert(
            abi.encodeWithSelector(Stake.Stake__upkeepNotNeeded.selector, currentBalance, numOfPlayers, sCondition)
        );
        stake.performUpkeep("");
    }

    //In the next test we will what we will do if we need to get data from emitted events in our test?
    function testPerformUpkeepUpdatesStakeConditionAndEmitsEVENTRequestID() public GetIntoStake {
        //arrange
        /* the modifier GetIntoStake will do part */

        //AcT
        vm.recordLogs();
        stake.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1]; // go see the Vm.sol (struct part) to understand this line

        //assert
        Stake.StakeCondition sCondition = stake.getStakeCondition();
        assert(uint256(requestId) > 0);
        assert(uint256(sCondition) == 1);
    }

    // FULFILL RANDOM WORDS //

    modifier ForkSkip() {
        if (block.chainid != LOCAL_CHAINID) {
            return;
        }
        _;
    }

    /**
     * @notice fuzz testing here, also see foundry.toml, we sent it to run with 1000 times which here will be 1000 diff requestids
     * After running this test set it to 256 default in .toml file as it take a bit longer to do this much test,1000s fine tho
     */
    function testFullfillRandomWordsCanOnlyBeCalledAfterPerfromUpkeep(uint256) public GetIntoStake ForkSkip {
        /**
         * @note for tgis test go to VRFC 2.5 Mock fullfill randomwords function to understand,we will try that function revert here
         */

        //arrange
        /* the modifeir does this part */

        // act // assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfcoordinator).fulfillRandomWords(0, address(stake));
    }

    function testFullfillrandomWordsPicksAwinnerResetthearrayAndSendtheMoneytoTheWinner()
        public
        GetIntoStake
        ForkSkip
    {
        //arrange

        uint256 addtionalEntrants = 4; // 5 toatal
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (uint256 i = startingIndex; i < startingIndex + addtionalEntrants; i++) {
            address newPlayer = address(uint160(i)); // how you convert uint to address
            hoax(newPlayer, PLAYER_BALANCE_STARTING);
            stake.StakeEntry{value: entryfee}();
        }
        uint256 startTimeStamp = stake.getLastTimestamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // uint256 startTimeStamp = stake.getLastTimestamp();

        //Act

        vm.recordLogs();
        console.log("Before performUpkeep:", stake.getLastTimestamp());
        stake.performUpkeep("");
        console.log("After performUpkeep:", stake.getLastTimestamp());
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        VRFCoordinatorV2_5Mock(vrfcoordinator).fulfillRandomWords(uint256(requestId), address(stake));

        //assert
        address recentWinner = stake.getMostrecentWinner();
        Stake.StakeCondition sCondition = stake.getStakeCondition();
        uint256 winnerBalance = recentWinner.balance;
        uint256 winnerReward = entryfee * (addtionalEntrants + 1);

        uint256 endingTimeStamp = stake.getLastTimestamp();

        assert(recentWinner == expectedWinner);
        assert(uint256(sCondition) == 0);
        assert(winnerBalance == winnerStartingBalance + winnerReward);
        //assert
        assert(endingTimeStamp > startTimeStamp);
    }
}
