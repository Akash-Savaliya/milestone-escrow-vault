// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EscrowTypes {
    error Escrow__InvalidAddress();
    error Escrow__InvalidAmount();
    error Escrow__JobNotFound();
    error Escrow__Unauthorized();
    error Escrow__InvalidState();
    error Escrow__TransferFailed();

    enum JobStatus {
        Created,
        Assigned,
        InProgress,
        Completed,
        Disputed,
        Cancelled
    }

    enum MilestoneStatus {
        Funded,
        Submitted,
        Paid,
        Disputed
    }

    enum DisputeStatus {
        None,
        Active,
        Resolved
    }

    struct MileStone {
        uint256 id;
        uint256 amount;
        MilestoneStatus status;
        bytes32 proofHash;
    }

    struct Dispute {
        uint256 jobId;
        uint256 milestoneId;
        address initiator;
        uint256 amount;
        DisputeStatus status;
    }

    struct Job {
        uint256 id;
        address client;
        address freelancer;
        address arbiter;
        uint256 totalBudget;
        uint256 fundedAmount;
        JobStatus status;
        DisputeStatus disputeStatus;
        bytes32 metadataHash;
    }
}
