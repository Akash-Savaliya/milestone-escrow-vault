// SPDX-License-Identifier: MIT
pragma solidity ^0.8.37;

import { Test } from "lib/forge-std/src/Test.sol";
import { EscrowMarketplace } from "../src/EscrowMarketplace.sol";
import { EscrowTypes } from "../src/types/EscrowTypes.sol";
import { IEscrowMarketplace } from "../src/interfaces/IEscrowMarketplace.sol";

contract EscrowMarketplaceMock is EscrowMarketplace {
    constructor() EscrowMarketplace() {
        // set dummy list in s_jobs in EscrowMarketplace for testing
        for (uint256 i = 0; i < 3; i++) {
            s_jobs[i] = EscrowTypes.Job({ // s_jobs acccess from EscrowMarketplace by inheriting the EscrowMarketplace contract
                id: i,
                arbiter: address(1),
                client: address(msg.sender), // address(msg.sender) is the address of the EscrowMarketplaceTest contract
                freelancer: address(0x01),
                status: EscrowTypes.JobStatus.Created,
                totalBudget: 10,
                fundedAmount: 0,
                disputeStatus: EscrowTypes.DisputeStatus.None,
                metadataHash: bytes32(0)
            });
        }
        s_nextJobId = 2;
    }

    /* Another way is, to create function here and in function do same like
    above constuctor but call this funcion in the EscrowMarketplaceTest setUp() function
    or better approach is to call this function from specific test function which need dummy s_jobs for testing */

    function setJobStatus(uint256 jobId, EscrowTypes.JobStatus status) public {
        s_jobs[jobId].status = status;
    }

    function setMilestoneStatus(uint256 jobId, uint256 milestoneId, EscrowTypes.MilestoneStatus status) public {
        s_jobMilestones[jobId][milestoneId].status = status;
    }

    function getNextJobId() external view returns (uint256) {
        return s_nextJobId;
    }

    function getMilestones(uint256 jobId) external view returns (EscrowTypes.MileStone[] memory) {
        return s_jobMilestones[jobId];
    }

    function setDisputeStatus(uint256 jobId, uint256 disputeId, EscrowTypes.DisputeStatus status) public {
        s_disputes[jobId][disputeId].status = status;
    }

    function addDispute(uint256 jobId, uint256 milestoneId) public {
        s_disputes[jobId].push(
            EscrowTypes.Dispute({
                jobId: jobId,
                milestoneId: milestoneId,
                initiator: msg.sender,
                amount: s_jobMilestones[jobId][milestoneId].amount,
                status: EscrowTypes.DisputeStatus.Active
            })
        );
    }
}

contract EscrowMarketplaceTest is Test {
    EscrowMarketplaceMock public escrowMarketplace;

    function setUp() public {
        escrowMarketplace = new EscrowMarketplaceMock();
    }

    /* Third appoach to set jobs in s_jobs in EscrowMarketplace is create addJobs function here and call this
    function in the setUp() function or call this function from specific test function which need dummy s_jobs for testing */

    function test_createJob_RevertIf_ArbiterIsZeroAddress() public {
        vm.expectRevert(EscrowTypes.Escrow__InvalidAddress.selector);
        escrowMarketplace.createJob(address(0), 10, keccak256(abi.encodePacked("Job meta data hash")));
    }

    function test_createJob_Pass() public {
        uint256 currentJobId = escrowMarketplace.getNextJobId();

        vm.expectEmit(true, true, true, true);
        emit IEscrowMarketplace.JobCreated(currentJobId + 1, address(0x11), address(0x22));

        vm.prank(address(0x11));
        uint256 newJobId =
            escrowMarketplace.createJob(address(0x22), 20, keccak256(abi.encodePacked("Job meta data hash")));
        currentJobId += 1;

        (uint256 id, address client,, address arbiter, uint256 totalBudget,,,, bytes32 metadataHash) =
            escrowMarketplace.s_jobs(currentJobId);
        assertEq(newJobId, currentJobId, "Job id not increasing properly");
        assertEq(id, currentJobId, "Job not found");
        assertEq(client == address(0x11), true, "Client address missmatch");
        assertEq(arbiter, address(0x22), "Arbiter address missmatch");
        assertEq(totalBudget, 20, "Total budget missmatch");
        assertEq(metadataHash, keccak256(abi.encodePacked("Job meta data hash")), "Metadata hash missmatch");
    }

    function test_assignFreelancer_RevertIf_UserIsNotClient() public {
        vm.expectRevert(EscrowTypes.Escrow__Unauthorized.selector);
        vm.prank(address(0x00));
        escrowMarketplace.assignFreelancer(0, address(0x11));
    }

    function test_assignFreelancer_RevertIf_FreelancerIsZeroAddress() public {
        vm.expectRevert(EscrowTypes.Escrow__InvalidAddress.selector);
        escrowMarketplace.assignFreelancer(0, address(0));
    }

    function test_assignFreelancer_RevertIf_JobStatusIsNotCreated() public {
        escrowMarketplace.setJobStatus(0, EscrowTypes.JobStatus.Assigned);
        vm.expectRevert(EscrowTypes.Escrow__InvalidState.selector);
        escrowMarketplace.assignFreelancer(0, address(0x11));
    }

    function test_assignFreelancer_Pass() public {
        vm.expectEmit();
        emit IEscrowMarketplace.FreelancerAssignedToJob(0, address(0x11));

        vm.expectEmit(true, true, true, true);
        emit IEscrowMarketplace.JobAssigned(0, address(0x11));

        escrowMarketplace.assignFreelancer(0, address(0x11));

        (,, address freelancer,,,,,,) = escrowMarketplace.s_jobs(0);
        assertEq(freelancer, address(0x11), "Freelancer address missmatch");
    }

    function test_createMilestone_RevertIf_NotClient() public {
        vm.expectRevert(EscrowTypes.Escrow__Unauthorized.selector);
        vm.prank(address(0x00));
        escrowMarketplace.createMilestone(0, 10, keccak256(abi.encodePacked("Milestone description hash")));
    }

    function test_createMilestone_RevertIf_AmountNotSent() public {
        vm.expectRevert(EscrowTypes.Escrow__InvalidAmount.selector);
        escrowMarketplace.createMilestone(0, 10, keccak256(abi.encodePacked("Milestone description hash")));
    }

    function test_createMilestone_RevertIf_AmountIsZero() public {
        vm.expectRevert(EscrowTypes.Escrow__InvalidAmount.selector);
        escrowMarketplace.createMilestone(0, 0, keccak256(abi.encodePacked("Milestone description hash")));
    }

    function test_createMilestone_RevertIf_MsgValueIsNotEqualToAmount() public {
        vm.expectRevert(EscrowTypes.Escrow__InvalidAmount.selector);
        escrowMarketplace.createMilestone{ value: 5 }(0, 10, keccak256(abi.encodePacked("Milestone description hash")));
    }

    function test_createMilestone_Pass() public {
        uint256 jobId = 0;
        uint256 amount = 10;

        vm.expectEmit(true, true, true, true);
        emit IEscrowMarketplace.MilestoneCreated(1);

        vm.expectEmit(true, true, true, true);
        emit IEscrowMarketplace.JobFunded(jobId, 1, 10);

        escrowMarketplace.createMilestone{ value: 10 }(
            jobId, amount, keccak256(abi.encodePacked("Milestone description hash"))
        );

        EscrowTypes.MileStone[] memory milestones = escrowMarketplace.getMilestones(jobId);
        assertEq(milestones.length, 1, "Milestone not created");
        assertEq(milestones[0].id, 1, "Milestone ID mismatch");
        assertEq(milestones[0].amount, amount, "Milestone amount mismatch");
        assertEq(uint8(milestones[0].status), uint8(EscrowTypes.MilestoneStatus.Funded), "Status mismatch");

        (,,,,, uint256 fundedAmount,,,) = escrowMarketplace.s_jobs(jobId);
        assertEq(fundedAmount, amount, "Funded amount missmatch");
    }

    function test_submitMilestone_RevertIf_NotFreelancer() public {
        vm.expectRevert(EscrowTypes.Escrow__Unauthorized.selector);
        escrowMarketplace.submitMilestone(0, 0);
    }

    function test_submitMilestone_RevertIf_MilestoneIdIsOutOfBounds() public {
        vm.expectRevert(EscrowTypes.Escrow__InvalidState.selector);
        vm.prank(address(0x01));
        escrowMarketplace.submitMilestone(0, 0);
    }

    function addMilestone(uint256 jobId) private {
        escrowMarketplace.createMilestone{ value: 10 }(
            jobId, 10, keccak256(abi.encodePacked("Milestone description hash"))
        );
    }

    function test_submitMilestone_RevertIf_MilestoneStatusIsNotFunded() public {
        addMilestone(0);
        escrowMarketplace.setMilestoneStatus(0, 0, EscrowTypes.MilestoneStatus.Submitted);
        vm.expectRevert(EscrowTypes.Escrow__InvalidState.selector);
        vm.prank(address(0x01));
        escrowMarketplace.submitMilestone(0, 0);
    }

    function test_submitMilestone_RevertIf_JobStatusIsNotAssigned() public {
        addMilestone(0);
        vm.prank(address(0x01));
        escrowMarketplace.submitMilestone(0, 0);
        (,,,,,, EscrowTypes.JobStatus jobStatus,,) = escrowMarketplace.s_jobs(0);

        assertEq(uint8(jobStatus), uint8(EscrowTypes.JobStatus.Created), "Job status should remain unchanged");
    }

    function test_submitMilestone_Pass() public {
        addMilestone(0);
        escrowMarketplace.setJobStatus(0, EscrowTypes.JobStatus.Assigned);
        vm.expectEmit(true, true, true, true);
        emit IEscrowMarketplace.JobStatusUpdated(0, EscrowTypes.JobStatus.InProgress);
        vm.expectEmit(true, true, true, true);
        emit IEscrowMarketplace.MilestoneSubmitted(0, 0);
        vm.prank(address(0x01));
        escrowMarketplace.submitMilestone(0, 0);

        (,, EscrowTypes.MilestoneStatus milestoneStatus,) = escrowMarketplace.s_jobMilestones(0, 0);

        (,,,,,, EscrowTypes.JobStatus jobStatus,,) = escrowMarketplace.s_jobs(0);

        assertEq(
            uint8(milestoneStatus), uint8(EscrowTypes.MilestoneStatus.Submitted), "Milestone status should be submitted"
        );
        assertEq(
            uint8(jobStatus), uint8(EscrowTypes.JobStatus.InProgress), "Job status should be changed to in progress"
        );
    }

    function test_approveAndPayMilestone_RevertIf_NotClient() public {
        vm.expectRevert(EscrowTypes.Escrow__Unauthorized.selector);
        vm.prank(address(0x11));
        escrowMarketplace.approveAndPayMilestone(0, 0);
    }

    function test_approveAndPayMilestone_RevertIf_MilestoneIdIsOutOfBounds() public {
        vm.expectRevert(EscrowTypes.Escrow__InvalidState.selector);
        escrowMarketplace.approveAndPayMilestone(0, 0);
    }

    function test_approveAndPayMilestone_RevertIf_MilestoneStatusIsNotFunded() public {
        addMilestone(0);
        escrowMarketplace.setMilestoneStatus(0, 0, EscrowTypes.MilestoneStatus.Funded);
        vm.expectRevert(EscrowTypes.Escrow__InvalidState.selector);
        escrowMarketplace.approveAndPayMilestone(0, 0);
    }

    function test_approveAndPayMilestone_RevertIf_PaymentFailed() public {
        addMilestone(0);
        escrowMarketplace.setMilestoneStatus(0, 0, EscrowTypes.MilestoneStatus.Submitted);
        vm.expectRevert(EscrowTypes.Escrow__TransferFailed.selector);
        vm.deal(address(escrowMarketplace), 5);
        escrowMarketplace.approveAndPayMilestone(0, 0);
    }

    function test_approveAndPayMilestone_Pass() public {
        addMilestone(0);
        escrowMarketplace.setMilestoneStatus(0, 0, EscrowTypes.MilestoneStatus.Submitted);
        vm.expectEmit(true, true, true, true);
        emit IEscrowMarketplace.MilestonePaid(0);
        escrowMarketplace.approveAndPayMilestone(0, 0);

        (,, EscrowTypes.MilestoneStatus milestoneStatus,) = escrowMarketplace.s_jobMilestones(0, 0);
        assertEq(uint8(milestoneStatus), uint8(EscrowTypes.MilestoneStatus.Paid), "Milestone status should be paid");
    }

    function test_raiseDispute_RevertIf_MilestoneIdIsOutOfBounds() public {
        vm.expectRevert(EscrowTypes.Escrow__InvalidState.selector);
        escrowMarketplace.raiseDispute(1, 0);
    }

    function test_raiseDispute_RevertIf_SenderIsNotClientOrFreelancer() public {
        addMilestone(0);
        vm.prank(address(0x11));
        vm.expectRevert(EscrowTypes.Escrow__Unauthorized.selector);
        escrowMarketplace.raiseDispute(0, 0);
    }

    function test_raiseDispute_RevertIf_JobStatusIsNotInProgress() public {
        vm.expectRevert(EscrowTypes.Escrow__InvalidState.selector);
        escrowMarketplace.raiseDispute(0, 0);
    }

    function test_raiseDispute_RevertIf_MileStoneStatusIsPaidOrDisputed() public {
        addMilestone(0);
        escrowMarketplace.setJobStatus(0, EscrowTypes.JobStatus.InProgress);
        escrowMarketplace.setMilestoneStatus(0, 0, EscrowTypes.MilestoneStatus.Paid);
        vm.expectRevert(EscrowTypes.Escrow__InvalidState.selector);
        escrowMarketplace.raiseDispute(0, 0);
    }

    function test_raiseDispute_Pass() public {
        addMilestone(0);
        escrowMarketplace.setJobStatus(0, EscrowTypes.JobStatus.InProgress);
        vm.expectEmit(true, true, true, true);
        emit IEscrowMarketplace.DisputeRaised(0, address(this));
        escrowMarketplace.raiseDispute(0, 0);

        (,,,,,, EscrowTypes.JobStatus jobStatus, EscrowTypes.DisputeStatus disputeStatus,) = escrowMarketplace.s_jobs(0);

        (,, EscrowTypes.MilestoneStatus milestoneStatus,) = escrowMarketplace.s_jobMilestones(0, 0);

        assertEq(
            uint8(milestoneStatus), uint8(EscrowTypes.MilestoneStatus.Disputed), "Milestone status should be disputed"
        );
        assertEq(uint8(disputeStatus), uint8(EscrowTypes.DisputeStatus.Active), "Dispute status should be active");
        assertEq(uint8(jobStatus), uint8(EscrowTypes.JobStatus.Disputed), "Dispute status should be active");
    }

    function test_resolveDispute_RevertIf_WinnerAddressInvalid() public {
        vm.expectRevert(EscrowTypes.Escrow__InvalidAddress.selector);
        escrowMarketplace.resolveDispute(0, address(0), 0, 0);
    }

    function test_resolveDispute_RevertIf_MilestoneIdIsOutOfBounds() public {
        vm.expectRevert(EscrowTypes.Escrow__InvalidState.selector);
        escrowMarketplace.resolveDispute(0, address(this), 0, 0);
    }

    function test_resolveDispute_RevertIf_WinnerIsNotClientOrFreelancer() public {
        addMilestone(0);
        vm.expectRevert(EscrowTypes.Escrow__Unauthorized.selector);
        escrowMarketplace.resolveDispute(0, address(0x11), 0, 0);
    }

    function test_resolveDispute_RevertIf_SenderIsNotArbiter() public {
        addMilestone(0);
        vm.expectRevert(EscrowTypes.Escrow__Unauthorized.selector);
        escrowMarketplace.resolveDispute(0, address(0x01), 0, 0);
    }

    function test_resolveDispute_RevertIf_JobStatusIsNotDisputed() public {
        addMilestone(0);
        vm.expectRevert(EscrowTypes.Escrow__InvalidState.selector);
        vm.prank(address(1));
        escrowMarketplace.resolveDispute(0, address(0x01), 0, 0);
    }

    function test_resolveDispute_RevertIf_MilestoneStatusIsNotDisputed() public {
        addMilestone(0);
        escrowMarketplace.setJobStatus(0, EscrowTypes.JobStatus.Disputed);
        vm.expectRevert(EscrowTypes.Escrow__InvalidState.selector);
        vm.prank(address(1));
        escrowMarketplace.resolveDispute(0, address(0x01), 0, 0);
    }

    function test_resolveDispute_RevertIf_DiscputeStatusIsNotActive() public {
        addMilestone(0);
        escrowMarketplace.setJobStatus(0, EscrowTypes.JobStatus.Disputed);
        escrowMarketplace.setMilestoneStatus(0, 0, EscrowTypes.MilestoneStatus.Disputed);
        escrowMarketplace.addDispute(0, 0);
        escrowMarketplace.setDisputeStatus(0, 0, EscrowTypes.DisputeStatus.Resolved);
        vm.expectRevert(EscrowTypes.Escrow__InvalidState.selector);
        vm.prank(address(1));
        escrowMarketplace.resolveDispute(0, address(0x01), 0, 0);
    }

    function test_resolveDispute_RevertIf_TransferFailed() public {
        addMilestone(0);
        escrowMarketplace.setJobStatus(0, EscrowTypes.JobStatus.Disputed);
        escrowMarketplace.setMilestoneStatus(0, 0, EscrowTypes.MilestoneStatus.Disputed);
        escrowMarketplace.addDispute(0, 0);
        vm.prank(address(1));
        vm.deal(address(escrowMarketplace), 5);
        vm.expectRevert(EscrowTypes.Escrow__TransferFailed.selector);
        escrowMarketplace.resolveDispute(0, address(0x01), 0, 0);
    }

    function test_resolveDispute_Pass() public {
        addMilestone(0);
        escrowMarketplace.setJobStatus(0, EscrowTypes.JobStatus.Disputed);
        escrowMarketplace.setMilestoneStatus(0, 0, EscrowTypes.MilestoneStatus.Disputed);
        escrowMarketplace.addDispute(0, 0);
        vm.prank(address(1));
        vm.expectEmit(true, true, true, true);
        emit IEscrowMarketplace.DisputeResolved(0, address(0x01), 0);
        escrowMarketplace.resolveDispute(0, address(0x01), 0, 0);

        (,, EscrowTypes.MilestoneStatus milestoneStatus,) = escrowMarketplace.s_jobMilestones(0, 0);
        assertEq(uint8(milestoneStatus), uint8(EscrowTypes.MilestoneStatus.Paid), "Milestone status should be paid");

        (,,,,,, EscrowTypes.JobStatus jobStatus, EscrowTypes.DisputeStatus jobDisputeStatus,) =
            escrowMarketplace.s_jobs(0);

        (,,,, EscrowTypes.DisputeStatus disputeStatus) = escrowMarketplace.s_disputes(0, 0);

        assertEq(uint8(jobStatus), uint8(EscrowTypes.JobStatus.Completed), "Job status should be completed");

        assertEq(
            uint8(jobDisputeStatus), uint8(EscrowTypes.DisputeStatus.Resolved), "Job dispute status should be Resolved"
        );

        assertEq(uint8(disputeStatus), uint8(EscrowTypes.DisputeStatus.Resolved), "Dispute status should be resolved");
    }
}
