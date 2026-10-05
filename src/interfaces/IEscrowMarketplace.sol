// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { EscrowTypes } from "../types/EscrowTypes.sol";

interface IEscrowMarketplace {
    event JobCreated(uint256 indexed jobId, address indexed client, address indexed arbiter);

    event JobAssigned(uint256 indexed jobId, address indexed freelancer);

    event MilestoneCreated(uint256 indexed milestoneId);

    event MilestoneSubmitted(uint256 indexed jobId, uint256 milestoneId);

    event MilestonePaid(uint256 milestoneId);

    event DisputeRaised(uint256 indexed jobId, address indexed initiator);

    event FreelancerAssignedToJob(uint256 indexed jobId, address indexed freelancer);

    event JobStatusUpdated(uint256 indexed jobId, EscrowTypes.JobStatus indexed status);

    event JobFunded(uint256 indexed jobId, uint256 indexed milestoneId, uint256 amount);

    event DisputeResolved(uint256 indexed jobId, address winner, uint256 amount);

    function createJob(address arbiter, uint256 totalBudget, bytes32 metadataHash) external returns (uint256 jobId);

    function assignFreelancer(uint256 jobId, address freelancer) external;

    function createMilestone(uint256 jobId, uint256 amount, bytes32 descriptionHash) external payable;

    function submitMilestone(uint256 jobId, uint256 milestoneId) external;

    function raiseDispute(uint256 jobId, uint256 milestoneId) external;

    function resolveDispute(uint256 jobId, address winner, uint256 milestoneId) external;

    function approveAndPayMilestone(uint256 jobId, uint256 milestoneId) external payable;
}
