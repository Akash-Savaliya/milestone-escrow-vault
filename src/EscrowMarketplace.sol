// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IEscrowMarketplace } from "./interfaces/IEscrowMarketplace.sol";
import { EscrowTypes } from "./types/EscrowTypes.sol";

abstract contract EscrowMarketplace is ReentrancyGuard, IEscrowMarketplace {
    uint256 private s_nextJobId = 0;

    mapping(uint256 => EscrowTypes.Job) public s_jobs;
    mapping(uint256 => EscrowTypes.MileStone[]) public s_jobMilestones;
    mapping(uint256 => EscrowTypes.Dispute[]) public s_disputes;

    modifier onlyClient(uint256 jobId) {
        if (s_jobs[jobId].client != msg.sender) {
            revert EscrowTypes.Escrow__Unauthorized();
        }
        _;
    }

    modifier onlyFreelancer(uint256 jobId) {
        if (s_jobs[jobId].freelancer != msg.sender) {
            revert EscrowTypes.Escrow__Unauthorized();
        }
        _;
    }

    function createJob(address arbiter, uint256 totalBudget, bytes32 metadataHash)
        external
        override
        returns (uint256 jobId)
    {
        if (arbiter == address(0)) revert EscrowTypes.Escrow__InvalidAddress();

        jobId = ++s_nextJobId;
        s_jobs[jobId] = EscrowTypes.Job({
            id: jobId,
            arbiter: arbiter,
            client: msg.sender,
            freelancer: address(0),
            status: EscrowTypes.JobStatus.Created,
            totalBudget: totalBudget,
            fundedAmount: 0,
            disputeStatus: EscrowTypes.DisputeStatus.None,
            metadataHash: metadataHash
        });

        emit JobCreated(jobId, msg.sender, arbiter);
    }

    function assignFreelancer(uint256 jobId, address freelancer) external override onlyClient(jobId) {
        if (freelancer == address(0)) {
            revert EscrowTypes.Escrow__InvalidAddress();
        }
        if (s_jobs[jobId].status != EscrowTypes.JobStatus.Created) {
            revert EscrowTypes.Escrow__InvalidState();
        }

        s_jobs[jobId].freelancer = freelancer;
        emit FreelancerAssignedToJob(jobId, freelancer);

        s_jobs[jobId].status = EscrowTypes.JobStatus.Assigned;
        emit JobAssigned(jobId, freelancer);
    }

    function createMilestone(uint256 jobId, uint256 amount, bytes32 descriptionHash)
        external
        payable
        override
        onlyClient(jobId)
    {
        if (msg.value != amount || amount == 0) {
            revert EscrowTypes.Escrow__InvalidAmount();
        }

        uint256 newMilestoneId = s_jobMilestones[jobId].length + 1;

        s_jobMilestones[jobId].push(
            EscrowTypes.MileStone({
                id: newMilestoneId,
                amount: amount,
                proofHash: descriptionHash,
                status: EscrowTypes.MilestoneStatus.Funded
            })
        );
        s_jobs[jobId].fundedAmount += amount;
        emit JobFunded(jobId, newMilestoneId, amount);

        emit MilestoneCreated(newMilestoneId);
    }

    function submitMilestone(uint256 jobId, uint256 milestoneId) external override onlyFreelancer(jobId) {
        if (milestoneId >= s_jobMilestones[jobId].length) {
            revert EscrowTypes.Escrow__InvalidState();
        }

        EscrowTypes.MileStone storage milestone = s_jobMilestones[jobId][milestoneId];

        if (milestone.status != EscrowTypes.MilestoneStatus.Funded) {
            revert EscrowTypes.Escrow__InvalidState();
        }

        milestone.status = EscrowTypes.MilestoneStatus.Submitted;

        if (s_jobs[jobId].status == EscrowTypes.JobStatus.Assigned) {
            s_jobs[jobId].status = EscrowTypes.JobStatus.InProgress;
            emit JobStatusUpdated(jobId, EscrowTypes.JobStatus.InProgress);
        }

        emit MilestoneSubmitted(jobId, milestoneId);
    }

    function approveAndPayMilestone(uint256 jobId, uint256 milestoneId)
        external
        payable
        override
        nonReentrant
        onlyClient(jobId)
    {
        if (milestoneId >= s_jobMilestones[jobId].length) {
            revert EscrowTypes.Escrow__InvalidState();
        }

        EscrowTypes.MileStone storage milestone = s_jobMilestones[jobId][milestoneId];

        if (milestone.status != EscrowTypes.MilestoneStatus.Submitted) {
            revert EscrowTypes.Escrow__InvalidState();
        }

        milestone.status = EscrowTypes.MilestoneStatus.Paid;
        address freelancer = s_jobs[jobId].freelancer;
        uint256 payoutAmount = milestone.amount;
        emit MilestonePaid(milestoneId);
        (bool success,) = payable(freelancer).call{ value: payoutAmount }("");
        if (!success) revert EscrowTypes.Escrow__TransferFailed();
    }

    function raiseDispute(uint256 jobId, uint256 milestoneId) external override {
        if (milestoneId >= s_jobMilestones[jobId].length) {
            revert EscrowTypes.Escrow__InvalidState();
        }

        EscrowTypes.Job storage job = s_jobs[jobId];

        if (!(job.client == msg.sender || job.freelancer == msg.sender)) {
            revert EscrowTypes.Escrow__Unauthorized();
        }

        if (job.status != EscrowTypes.JobStatus.InProgress) {
            revert EscrowTypes.Escrow__InvalidState();
        }

        EscrowTypes.MileStone storage milestone = s_jobMilestones[jobId][milestoneId];

        if (
            milestone.status == EscrowTypes.MilestoneStatus.Paid
                || milestone.status == EscrowTypes.MilestoneStatus.Disputed
        ) {
            revert EscrowTypes.Escrow__InvalidState();
        }

        milestone.status = EscrowTypes.MilestoneStatus.Disputed;
        job.status = EscrowTypes.JobStatus.Disputed;
        job.disputeStatus = EscrowTypes.DisputeStatus.Active;

        s_disputes[jobId].push(
            EscrowTypes.Dispute({
                jobId: jobId,
                milestoneId: milestoneId,
                initiator: msg.sender,
                amount: milestone.amount,
                status: EscrowTypes.DisputeStatus.Active
            })
        );

        emit DisputeRaised(jobId, msg.sender);
    }

    function resolveDispute(uint256 jobId, address winner, uint256 milestoneId) external override nonReentrant {
        if (winner == address(0)) revert EscrowTypes.Escrow__InvalidAddress();

        if (milestoneId >= s_jobMilestones[jobId].length) {
            revert EscrowTypes.Escrow__InvalidState();
        }

        EscrowTypes.Job storage job = s_jobs[jobId];

        if (winner != job.client && winner != job.freelancer) {
            revert EscrowTypes.Escrow__Unauthorized();
        }

        if (msg.sender != job.arbiter) {
            revert EscrowTypes.Escrow__Unauthorized();
        }

        if (job.status != EscrowTypes.JobStatus.Disputed) {
            revert EscrowTypes.Escrow__InvalidState();
        }

        EscrowTypes.MileStone storage milestone = s_jobMilestones[jobId][milestoneId];

        if (milestone.status != EscrowTypes.MilestoneStatus.Disputed) {
            revert EscrowTypes.Escrow__InvalidState();
        }

        milestone.status = EscrowTypes.MilestoneStatus.Paid;
        job.status = EscrowTypes.JobStatus.Completed;
        job.disputeStatus = EscrowTypes.DisputeStatus.Resolved;

        address winnerAddress = winner;
        emit DisputeResolved(jobId, winner, milestoneId);
        (bool success,) = payable(winnerAddress).call{ value: milestone.amount }("");

        if (!success) revert EscrowTypes.Escrow__TransferFailed();
    }
}
