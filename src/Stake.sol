// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

/**
 * @title A Stake contract
 * @author Wasim Choudhary
 * @notice This contracts shows how to create a fully functioning Stake contract
 * @dev Implementing Chainlink VRFv2.5 and Automation !
 */

contract Stake is VRFConsumerBaseV2Plus, AutomationCompatibleInterface{
    /**
     * @notice errors
     */
    error Stake__Insufficient_Eth_Entryfee();
    error Stake__NotEnoughTimePassed_ToPickWinner();
    error STake__TransferFailedToThe_Winner();
    error Stake__EntryClosedAttheMoment();
    error Stake__NoOneWonTillNow();
    error Stake__IndexOutOfBounds();
    error Stake__upkeepNotNeeded(uint256 Contractbalance, uint256 Playerslength, uint256 /* or StakeCondition */ stakecondition);

    /**@notice Type variables */
    enum StakeCondition {
        OPEN, //0
        CALCULATING // 1
    }

    /**
     * @notice State Variables!
     */
    uint256 private immutable i_StakeEntryfee;
    uint256 private immutable i_StakeInterval; //Stake round to last in seconds
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    StakeCondition private s_StakeCondition;

    address payable[] private s_Players;
    address[]
        private s_winnersArray; /** @notice we can remove this too as We can get the logs offchain through events, but since want a getter function for all the winners, using it
    use s_winnersArray ^ on your own accord as it will cost gas */

    uint256 private s_lastTimeStamp;

    /**
     * @notice Events
     */
    event Stake_PlayerEntered(address indexed player);
    event Stake_WinnerListUpdated(address indexed Winners);
    event STake_RequestedWinnerId(uint256 indexed requestId);

    /**
     * @notice Constructor function!
     */
    constructor(
        uint256 entryfee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackgasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_StakeEntryfee = entryfee;
        i_StakeInterval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackgasLimit;
        s_lastTimeStamp = block.timestamp;
        s_StakeCondition = StakeCondition.OPEN;
    }

    function StakeEntry() external payable {
        
          if (s_StakeCondition != StakeCondition.OPEN) {
            revert Stake__EntryClosedAttheMoment();
        }

          if (msg.value < i_StakeEntryfee) {
            revert Stake__Insufficient_Eth_Entryfee();
        }
      
      
        s_Players.push(payable(msg.sender));
        emit Stake_PlayerEntered(msg.sender);
    }

    function checkUpkeep(
        bytes memory /* checkData */    // before it was calldata instead of memory but tweaked it a little for the performUpkeep function
    ) public view override returns (bool upkeepNeeded, bytes memory /* performData */) {
        /** @notice --
         
         * @dev This is the function called by  chainlink nodes  to check if the contract is ready for getting the winner.
         *
         * In order for upKkeepNeeded to be true,the follow below should be true -
         * 1. Time Interval must have passed for it.
         * 2. The contract Stake is OPEN(0). //enum type
         * 3. The contract must Have players or a balance or amount of eth to be sent to the winner thus, indirectly saying check if players have entered.
         * 4. The subscription must hold link like in the case of vrf
         *
         * @param - not used in this case
         * @return upkeepNeeded = true, provided if it's time to restart the Stake.
         */
        bool timeIntervalhasPassed = ((block.timestamp - s_lastTimeStamp) >
            i_StakeInterval);
        bool StakeIsOPEN = s_StakeCondition == StakeCondition.OPEN;
        bool checkForBalance = address(this).balance > 0;
        bool checkForPlayers = s_Players.length > 0;

        upkeepNeeded =
            timeIntervalhasPassed &&
            StakeIsOPEN &&
            checkForBalance &&
            checkForPlayers;
        // if any of the above is false then no upKeepNeeded;
        return (upkeepNeeded, hex"");
         //or  return (upkeepNeeded, "")
        
    }

    function performUpkeep(bytes calldata /* peformData */) external override {
    
       (bool upkeepNeeded,) = checkUpkeep("");
       if(!upkeepNeeded) {
        revert Stake__upkeepNotNeeded(address(this).balance,s_Players.length, uint256(s_StakeCondition));
        } /* or can use uint256 or StakeCondition as OPEN = 0,CAL =1, lets use uint256 instead of enum name */

        /*  // Little less readibility so using another syntax //
       uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false}) // if want to pay with sepolia eth then set it to true
                )
            })
        ); */


            s_StakeCondition = StakeCondition.CALCULATING;
             s_lastTimeStamp = block.timestamp;  //either update time here or in fulfillrandomWords
             //also it is best practice to include in both as now in can Track When Upkeep Was Performed and in fulfill Tracking When a New Round Begins after winner etc everything finsihed 
        

        


        //for bettr struct operation and understanding and also visit the chainlink vrf docs for more in dept knowledge
        VRFV2PlusClient.RandomWordsRequest
            memory requestStruct = VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });
        uint256 requestId = s_vrfCoordinator.requestRandomWords(requestStruct);
        emit STake_RequestedWinnerId(requestId); // icnluding this even though the vrfcoordinator emits the same event because to make our test easier!
   
    
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] calldata randomWords
    ) internal virtual override {
        
        uint256 IndexofWinner = randomWords[0] % s_Players.length;
        address payable recentWinner = s_Players[IndexofWinner];
        s_winnersArray.push(recentWinner);
       
        if (s_winnersArray.length > 1) {
            emit Stake_WinnerListUpdated(recentWinner);
        }

        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert STake__TransferFailedToThe_Winner();
        }

        s_StakeCondition = StakeCondition.OPEN;

        // s_Players = new address payable[](0); // this resetting of array method = consumes more gas there fore
        delete s_Players;// much prefered and gas efficient than the above array resetting method
        s_lastTimeStamp = block.timestamp;
       
    }

    /**
     * @notice Getter Functions below !
     */
    function getEntraceFee() external view returns (uint256) {
        return i_StakeEntryfee;
    }

    function getStakeCondition() external view returns (StakeCondition) {
        return s_StakeCondition;
    }

    function getAlltheWinnersList() external view returns (address[] memory) {
        if (s_winnersArray.length == 0) {
            revert Stake__NoOneWonTillNow();
        }
        return s_winnersArray;
    }

    function getWinnerByIndexNumber(
        uint256 index
    ) external view returns (address) {
        if (index >= s_winnersArray.length) {
            revert Stake__IndexOutOfBounds();
        }
        return s_winnersArray[index];
    }

    function getMostrecentWinner() external view returns (address) {
        if (s_winnersArray.length == 0) {
            revert Stake__NoOneWonTillNow();
        }
        return s_winnersArray[s_winnersArray.length - 1];
    }
    function getPlayersbyIndex(uint256 i) external view returns(address){
        return s_Players[i];
    }
    function getPlayers()external view returns(uint256){
        return s_Players.length;
    }
    function getLastTimestamp() external view returns(uint256){
        return s_lastTimeStamp;
    }

    function getInterval()external view returns(uint256){
        return i_StakeInterval;
    }
    
}
