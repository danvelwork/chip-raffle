// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ChipRaffle is ERC20, Ownable {
    uint256 public constant tokensPerRound = 50 * 10**18;
    uint256 public constant maxSupply = 21_000_000 * 10**18;
    uint256 public ethToChipRate = 100;
    uint256 public roundDuration = 10 seconds;
    uint256 public lastRoundTime;
    uint256 public roundNumber = 1;

    address[] public participants;
    mapping(address => uint256) public chipBalance;
    mapping(address => uint256) public maxDelegation;
    mapping(address => uint256) public roundChipUsage;
    mapping(address => bool) private isParticipant;

    event BurnForChips(address indexed user, uint256 ethAmount, uint256 chipsReceived);
    event SetMaxDelegation(address indexed user, uint256 maxChips);
    event RoundResult(address winner, uint256 roundNumber);

    constructor() ERC20("RewardToken", "RWT") Ownable(msg.sender) {
        lastRoundTime = block.timestamp;
    }

    function burnETHForChips() external payable {
        require(msg.value > 0, "Must send ETH to receive chips");
        uint256 chipsReceived = msg.value * ethToChipRate;
        chipBalance[msg.sender] += chipsReceived;
        emit BurnForChips(msg.sender, msg.value, chipsReceived);
    }

    function setMaxDelegation(uint256 maxChips) external {
        require(maxChips % 10 == 0 && maxChips <= 50, "Invalid max delegation");
        require(chipBalance[msg.sender] >= maxChips, "Insufficient chips for delegation");

        // Add to participants if not already included
        if (!isParticipant[msg.sender]) {
            participants.push(msg.sender);
            isParticipant[msg.sender] = true;
        }

        maxDelegation[msg.sender] = maxChips;
        emit SetMaxDelegation(msg.sender, maxChips);
    }

    function simulateRound() external {
        require(block.timestamp >= lastRoundTime + roundDuration, "Round duration not met");
        require(totalSupply() + tokensPerRound <= maxSupply, "Max supply reached");

        require(participants.length > 0, "No participants available");
        
        address winner = participants[randomIndex(participants.length)];
        _mint(winner, tokensPerRound);

        emit RoundResult(winner, roundNumber);
        adjustChipsUsage();

        lastRoundTime = block.timestamp;
        roundNumber++;
    }

    function randomIndex(uint256 participantsCount) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, address(this), roundNumber))) % participantsCount;
    }

    function adjustChipsUsage() internal {
        uint256[5] memory chipSlots = [uint256(10), 20, 30, 40, 50];
        
        for (uint256 i = 0; i < participants.length; i++) {
            address user = participants[i];
            uint256 maxChips = maxDelegation[user];
            uint256 chipsUsed = 0;

            for (uint256 j = 0; j < chipSlots.length; j++) {
                if (chipSlots[j] <= maxChips && chipBalance[user] >= chipSlots[j]) {
                    chipsUsed += chipSlots[j];
                    chipBalance[user] -= chipSlots[j];
                }
            }
            roundChipUsage[user] = chipsUsed;
        }
    }

    function getAllParticipants() external view returns (address[] memory) {
        return participants;
    }

    function getChipBalance(address user) external view returns (uint256) {
        return chipBalance[user];
    }

    receive() external payable {}
}
