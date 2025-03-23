// SPDX-License-Identifer: MIT

pragma solidity ^0.8.19;

// SPDX-License-Identifier: MIT

import {Test, console} from "forge-std/Test.sol";
import {DeployStake} from "script/DeployStake.s.sol";
import {Stake} from "src/Stake.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CreateSub} from "script/Interaction.s.sol";

contract StakeTest is StdCheats, Test {
    event Stake_PlayerEntered(address indexed player);
    event Stake_WinnerListUpdated(address indexed Winners);
    event STake_RequestedWinnerId(uint256 indexed requestId);

    Stake public stake;
    HelperConfig public helperconfig;

    uint256 entryfee;
    uint256 interval;
    address vrfcoordinator;
    bytes32 gaslane;
    uint256 subId;
    uint32 callbackgaslimit;

    address public PLAYER = makeAddr("Player");
    uint256 public constant PLAYER_BALANCE_STARTING = 20 ether;

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
    }

    modifier EnterStake() {
        vm.prank(PLAYER);
        stake.StakeEntry{value: entryfee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier DeployedContractsOnly() {
        if (block.chainid == 31337) {
            return;
        }
        try vm.activeFork() returns (uint256) {
            return;
        } catch {
            _;
        }
    }

    function testFullfillRandomWordsCanOnlyBeCalledAfterPerfromUpkeep() public EnterStake DeployedContractsOnly {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2_5Mock(vrfcoordinator).fulfillRandomWords(0, address(stake));
        vm.expectRevert("nonexistent request");

        VRFCoordinatorV2_5Mock(vrfcoordinator).fulfillRandomWords(1, address(stake));
    }

    function testFullfillrandomWordsPicksAwinnerResetthearrayAndSendtheMoneytoTheWinner()
        public
        EnterStake
        DeployedContractsOnly
    {
        uint256 addtionalEntrants = 4; // 5 total
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (uint256 i = startingIndex; i < startingIndex + addtionalEntrants; i++) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 5 ether);
            stake.StakeEntry{value: entryfee}();
        }
        uint256 startTimeStamp = stake.getLastTimestamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        vm.recordLogs();
        console.log("Before performUpkeep:", stake.getLastTimestamp());
        stake.performUpkeep("");
        console.log("After performUpkeep:", stake.getLastTimestamp());
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        VRFCoordinatorV2_5Mock(vrfcoordinator).fulfillRandomWords(uint256(requestId), address(stake));

        address recentWinner = stake.getMostrecentWinner();
        Stake.StakeCondition sCondition = stake.getStakeCondition();
        uint256 winnerBalance = recentWinner.balance;
        uint256 winnerReward = entryfee * (addtionalEntrants + 1);

        uint256 endingTimeStamp = stake.getLastTimestamp();

        assert(recentWinner == expectedWinner);
        assert(uint256(sCondition) == 0);
        assert(winnerBalance == winnerStartingBalance + winnerReward);
        assert(endingTimeStamp > startTimeStamp);
    }
}
