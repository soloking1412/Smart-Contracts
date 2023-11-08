// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrowdfundingPlatform {
    struct Campaign {
        string name;
        uint256 goalAmount;
        address creator;
        uint256 vestingPeriod;
        uint256 startTime;
        uint256 totalFunds;
    }

    Campaign[] public campaigns;
    mapping(uint256 => mapping(address => uint256)) public contributions;
    mapping(uint256 => mapping(address => uint256)) public vestedTokens;
    mapping(uint256 => uint256) public claimedTokens;

    event CampaignCreated(uint256 campaignId, string name, address creator, uint256 goalAmount, uint256 vestingPeriod);
    event FundsContributed(uint256 campaignId, address backer, uint256 amount);
    event TokensClaimed(uint256 campaignId, address backer, uint256 amount);

    function createCampaign(string memory name, uint256 goalAmount, uint256 vestingPeriod) external {
        require(goalAmount > 0, "Goal amount must be greater than zero");
        require(vestingPeriod > 0, "Vesting period must be greater than zero");
        uint256 campaignId = campaigns.length;
        campaigns.push(Campaign({
            name: name,
            goalAmount: goalAmount,
            creator: msg.sender,
            vestingPeriod: vestingPeriod,
            startTime: 0,
            totalFunds: 0
        }));
        emit CampaignCreated(campaignId, name, msg.sender, goalAmount, vestingPeriod);
    }

    function contributeToCampaign(uint256 campaignId, uint256 amount) external payable {
        Campaign storage campaign = campaigns[campaignId];
        require(campaign.creator != address(0), "Campaign does not exist");
        require(msg.value == amount, "Sent value must equal the contribution amount");
        require(campaign.totalFunds + amount <= campaign.goalAmount, "Exceeds campaign goal");
        
        if (campaign.startTime == 0) {
            campaign.startTime = block.timestamp;
        }
        
        campaign.totalFunds += amount;
        contributions[campaignId][msg.sender] += amount;
        emit FundsContributed(campaignId, msg.sender, amount);
    }

    function claimTokens(uint256 campaignId) external {
        Campaign storage campaign = campaigns[campaignId];
        require(campaign.creator != address(0), "Campaign does not exist");
        require(campaign.creator != msg.sender, "Creator cannot claim tokens");
        require(campaign.startTime > 0, "Vesting has not started");
        require(block.timestamp >= campaign.startTime + campaign.vestingPeriod, "Tokens not vested yet");
        
        uint256 vestedAmount = calculateVestedTokens(campaignId, msg.sender);
        require(vestedAmount > 0, "No tokens to claim");
        
        uint256 unclaimedAmount = vestedAmount - claimedTokens[campaignId];
        claimedTokens[campaignId] += unclaimedAmount;
        vestedTokens[campaignId][msg.sender] = claimedTokens[campaignId];
        emit TokensClaimed(campaignId, msg.sender, unclaimedAmount);
    }

    function calculateVestedTokens(uint256 campaignId, address backer) internal view returns (uint256) {
        Campaign storage campaign = campaigns[campaignId];
        uint256 elapsedTime = block.timestamp - campaign.startTime;
        if (elapsedTime >= campaign.vestingPeriod) {
            return contributions[campaignId][backer];
        } else {
            return (contributions[campaignId][backer] * elapsedTime) / campaign.vestingPeriod;
        }
    }
}
