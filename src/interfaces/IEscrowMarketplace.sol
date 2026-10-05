// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IEscrowMarketplace {
    event JobCreated(
        uint256 indexed jobId,
        address indexed client,
        address indexed arbiter
    );

    event JobAssigned(
        uint256 indexed jobId,
        address indexed freelancer,
        address indexed arbiter
    );

    event MilestoneCreated(
        uint256 indexed jobId,
        uint256 indexed milestoneId,
        uint256 amount
    );

    event MilestoneSubmitted(uint256 indexed jobId, uint256 milestoneId);

    event MilestonePaid(
        uint256 indexed jobId,
        uint256 milestoneId,
        address indexed freelancer,
        uint256 amount
    );

    event DisputeRaised(uint256 indexed jobId, address indexed initiator);

    event DisputeResolved(
        uint256 indexed jobId,
        address winner,
        uint256 amount
    );

    function createJob(address arbiter) external returns (uint256 jobId);

    function assignFreelancer(uint256 jobId, address freelancer) external;

    function createMilestone(
        uint256 jobId,
        uint256 amount,
        string calldata descriptionHash
    ) external;

    function submitMilestone(uint256 jobId, uint256 milestoneId) external;

    function raiseDispute(uint256 jobId, address initiator) external;

    function resolveDispute(uint256 jobId, address winner) external;

    function approveAndPayMilestone(
        uint256 jobId,
        uint256 milestoneId
    ) external payable;
}
