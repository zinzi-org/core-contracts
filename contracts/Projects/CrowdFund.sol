// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.17;

import "../lib/Strings.sol";
import "../lib/Timers.sol";
import "../lib/SafeCast.sol";
import "../lib/Math.sol";
import "../Organizations/Members.sol";
import "./ProjectToken.sol";

contract CrowdFund {
    event ProjectCreated(uint256 projectTokenId);
    event ProposalApproved(uint256 projectTokenId, uint256 proposalIndex);
    event Proposal( uint256 projectTokenId, uint256 memberTokenId, uint256 proposalId);
    event ProposalVote(uint256 projectTokenId, uint256 proposalIndex);


    enum ProjectState {
        PROPOSAL,
        FUNDING,
        ASSIGNED,
        CANCELED,
        DISPUTED,
        COMPLETED
    }

    using Timers for Timers.BlockNumber;
    using SafeCast for uint256;
    using Math for uint256;

    struct ProjectCore {
        uint256 projectTokenId;
        uint256 projectHash;
        ProjectState projectState;
        Timers.BlockNumber startProposalPeriod;
        Timers.BlockNumber endProposalPeriod;
        Timers.BlockNumber startWorkPeriod;
        Timers.BlockNumber endWorkPeriod;
        mapping(address => bool) hasVoted;
        ProposalCore[] proposals;
        uint256 winningProposalIndex;
        
    }

    struct ProposalCore {
        uint256 memberTokenId;
        uint256 proposalHash;
        uint256 votes;
        uint256 proposalAmountNeeded;
        uint256 requestedTimeSpan;
        uint256 managerTokenId;
    }

    mapping(uint256 => ProjectCore) private _projects;

    address private _membersAddress;

    IProjectToken private _projectToken;

    uint256 private _balance;

    constructor(address membersAddress, address projectTokenAddress) {
        _membersAddress = membersAddress;
        _projectToken = IProjectToken(projectTokenAddress);
    }

    modifier onlyMember() {
        Members members = Members(_membersAddress);
        require(members.balanceOf(msg.sender) > 0, "Not a member");
        _;
    }

    modifier onlyOwner(uint256 tokenId) {
        require(
            _projectToken.ownerOf(tokenId) == msg.sender,
            "Not the token owner"
        );
        _;
    }

    modifier onlyManager(uint256 tokenId) {
        require(
            _projectToken.ownerOf(tokenId) == msg.sender,
            "Not the token owner"
        );
        _;
    }


    // ---- Project Functions ----

    function createProject(
        string memory projectName,
        string memory projectSummary,
        uint256 proposalPeriod
    ) public {
        uint256 projectTokenId = _projectToken.mintProject(msg.sender);
        ProjectCore storage core = _projects[projectTokenId];
        core.startProposalPeriod = Timers.BlockNumber(block.number.toUint64());
        core.endProposalPeriod = Timers.BlockNumber(
            (block.number + proposalPeriod).toUint64()
        );
        core.projectHash = generateProjectHash(projectName, projectSummary);
        core.projectTokenId = projectTokenId;
        core.projectState = ProjectState.PROPOSAL;
        emit ProjectCreated(projectTokenId);
    }

    function updateProjectHash(
        uint256 tokenId,
        string memory projectName,
        string memory projectSummary
    ) public {
        address owner = _projectToken.ownerOf(tokenId);
        require(msg.sender == owner, "Only owner of project token can ");
        require(
            _projects[tokenId].projectState == ProjectState.PROPOSAL,
            "Project must be in a proposing state"
        );
        _projects[tokenId].projectHash = generateProjectHash(
            projectName,
            projectSummary
        );
    }

    function generateProjectHash(
        string memory projectName,
        string memory projectSummary
    ) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(projectName, projectSummary)));
    }

    function projectState(
        uint256 projectTokenId
    ) public view returns (ProjectState) {
        ProjectCore storage project = _projects[projectTokenId];
        return project.projectState;
    }

    function projectDetails(
        uint256 projectTokenId
    ) public view returns (uint256, uint256, ProjectState) {
        ProjectCore storage project = _projects[projectTokenId];
        return (project.winningProposalIndex, project.projectHash, project.projectState);
    }


    function projectProposalDeadline(
        uint256 projectTokenId
    ) public view returns (uint256) {
        ProjectCore storage project = _projects[projectTokenId];
        return project.endProposalPeriod.getDeadline();
    }

    function projectWorkDeadline(
        uint256 projectTokenId
    ) public view returns (uint256) {
        ProjectCore storage project = _projects[projectTokenId];
        return project.endWorkPeriod.getDeadline();
    }

    function completeProject(uint256 tokenId, uint256 managerTokenId) onlyManager(managerTokenId) public {
        ProjectCore storage core = _projects[tokenId];
        require(
            core.proposals[core.winningProposalIndex].managerTokenId == managerTokenId,
            "Manager does not match winning proposal"
        );
        require(
            core.projectState == ProjectState.ASSIGNED,
            "Project must be in an assigned state"
        );
        require(core.endWorkPeriod.isExpired(), "Work period has not expired");
        core.projectState = ProjectState.COMPLETED;
    }

    function cancelProject(uint256 tokenId) onlyOwner(tokenId) public {
        ProjectCore storage core = _projects[tokenId];
        require(
            core.projectState == ProjectState.PROPOSAL,
            "Project must be in a proposing state"
        );
        require(core.endProposalPeriod.isExpired(), "Proposal period has not expired");
        core.projectState = ProjectState.CANCELED;
    }

    // ---- Proposal Functions ----

    function createProposal(
        uint256 memberId,
        uint256 projectId,
        string memory summary,
        uint256 amountNeeded,
        uint256 timeNeeded,
        uint256 managerTokenId
    ) public onlyMember {
        ProposalCore memory core;
        core.memberTokenId = memberId;
        core.proposalAmountNeeded = amountNeeded;
        core.requestedTimeSpan = timeNeeded;
        core.managerTokenId = managerTokenId;
        core.proposalHash = generateProposalHash(summary, projectId, memberId);
        uint256 proposalId = _projects[projectId].proposals.length;
        _projects[projectId].proposals.push(core);
        emit Proposal(projectId, memberId, proposalId);
    }

    function generateProposalHash(
        string memory summary,
        uint256 projectId,
        uint256 memberId
    ) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(summary, projectId, memberId)));
    }

    function updateProposal(
        uint256 projectTokenId,
        uint256 proposalIndex,
        string memory summary,
        uint256 amountNeeded,
        uint256 timeNeeded
    ) public onlyMember {
        ProposalCore storage core = _projects[projectTokenId].proposals[
            proposalIndex
        ];
        Members member = Members(_membersAddress);
        require(
            msg.sender == member.ownerOf(core.memberTokenId),
            "Proposal does not belong to member"
        );
        core.proposalHash = generateProposalHash(
            summary,
            projectTokenId,
            proposalIndex
        );
        core.proposalAmountNeeded = amountNeeded;
        core.requestedTimeSpan = timeNeeded;
    }

    function cancelProposal(
        uint256 projectTokenId,
        uint256 proposalIndex
    ) public onlyOwner(projectTokenId) {
        ProposalCore storage core = _projects[projectTokenId].proposals[
            proposalIndex
        ];
        require(
            core.votes == 0,
            "Proposal has already been voted on and cannot be cancelled"
        );
        delete _projects[projectTokenId].proposals[proposalIndex];
    }

    function disputeProposal(uint256 tokenId) public onlyOwner(tokenId) {
        ProjectCore storage core = _projects[tokenId];
        require(
            core.projectState == ProjectState.ASSIGNED,
            "Project must be in an assigned state"
        );
        core.projectState = ProjectState.DISPUTED;
    }

    function approveProposal(
        uint256 projectTokenId,
        uint256 proposalIndex
    ) public {
        ProjectCore storage core = _projects[projectTokenId];
        require(
            core.projectState == ProjectState.PROPOSAL,
            "Project must be in a proposal state"
        );
        require(core.endProposalPeriod.isExpired(), "Voting period has not expired");
        core.projectState = ProjectState.ASSIGNED;
        core.winningProposalIndex = proposalIndex;
        core.startWorkPeriod = Timers.BlockNumber(block.number.toUint64());
        core.endWorkPeriod = Timers.BlockNumber(
            (block.number + core.proposals[proposalIndex].requestedTimeSpan).toUint64()
        );
        emit ProposalApproved(projectTokenId, proposalIndex);
    }

    function getProposalDetails(
        uint256 projectTokenId,
        uint256 proposalIndex
    ) public view returns (ProposalCore memory) {
        ProjectCore storage core = _projects[projectTokenId];
        return core.proposals[proposalIndex];
    }

    // ---- Voting Functions ----

    function castVote(uint256 projectTokenId, uint256 proposalIndex) public {
        ProjectCore storage core = _projects[projectTokenId];
        require(core.hasVoted[msg.sender] == false, "Has already voted");
        core.hasVoted[msg.sender] = true;
        core.proposals[proposalIndex].votes += 1;
        if(core.proposals[proposalIndex].votes > core.proposals[core.winningProposalIndex].votes) {
            core.winningProposalIndex = proposalIndex;
        }
        emit ProposalVote(projectTokenId, proposalIndex);
    }

    function getVotes(
        uint256 projectTokenId,
        uint256 proposalIndex
    ) public view returns (uint256) {
        ProjectCore storage core = _projects[projectTokenId];
        return core.proposals[proposalIndex].votes;
    }

    function hasVoted(
        uint256 projectTokenId,
        address account
    ) public view returns (bool) {
        return _projects[projectTokenId].hasVoted[account];
    }


    // --- Utility Functions ---

    function transferFunds(address recipient, uint256 amount) private {
        require(address(this).balance >= amount, "Not enough balance");
        require(_balance >= amount, "Not enough balance");
        
        // If checks pass, proceed with the transfer
        payable(recipient).transfer(amount);
        
        // Then, update the balance
        _balance -= amount;
    }

    function getTotalBalance() public view returns (uint256) {
        return _balance;
    }
}
