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

    enum ProjectState {
        FUNDING,
        VOTING,
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
        Timers.BlockNumber voteEnd;
        ProjectState projectState;
        Timers.BlockNumber startWorkPeriod;
        Timers.BlockNumber endWorkPeriod;
        mapping(address => bool) hasVoted;
        ProposalCore[] proposals;
        uint256 ownerBudgetAmount;
        uint256 winningProposalIndex;
    }

    struct ProposalCore {
        uint256 memberTokenId;
        uint256 proposalHash;
        uint256 votes;
        uint256 proposalAmountNeeded;
        uint256 requestedTimeSpan;
    }

    mapping(uint256 => ProjectCore) private _projects;

    address private _membersAddress;

    IProjectToken private _projectToken;

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
        require(_projectToken.ownerOf(tokenId) == msg.sender, "Not the token owner");
        _;
    }

    modifier isVoting(uint256 tokenId) {
        require(
            _projects[tokenId].projectState == ProjectState.VOTING,
            "Incorrect project state"
        );
        _;
    }

    function mintProject(
        string memory nameP,
        string memory summary,
        uint256 ownerBudgetAmount,
        uint256 votingPeriod
    ) public {
        uint256 projectTokenId = _projectToken.mintProject(msg.sender);
        uint64 deadline = block.number.toUint64() + votingPeriod.toUint64();
        ProjectCore storage core = _projects[projectTokenId];
        core.projectHash = generateProjectHash(nameP, summary);
        core.projectTokenId = projectTokenId;
        core.projectState = ProjectState.FUNDING;
        core.voteEnd.setDeadline(deadline);
        core.ownerBudgetAmount = ownerBudgetAmount;
        emit ProjectCreated(projectTokenId);
    }

    function updateProjectHash(
        uint256 tokenId,
        string memory projectName,
        string memory projectSummary
    ) public isVoting(tokenId) {
        address owner = _projectToken.ownerOf(tokenId);
        require(msg.sender == owner, "Only owner of project token can ");
        _projects[tokenId].projectHash = generateProjectHash(
            projectName,
            projectSummary
        );
    }

    function updateProjectAmount(
        uint256 tokenId,
        uint256 amount
    ) public isVoting(tokenId) {
        address owner = _projectToken.ownerOf(tokenId);
        require(msg.sender == owner, "Only owner of project token can ");
        _projects[tokenId].ownerBudgetAmount = amount;
    }

    function generateProjectHash(
        string memory projectName,
        string memory projectSummary
    ) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(projectName, projectSummary)));
    }

    function createProposal(
        uint256 memberId,
        uint256 projectId,
        string memory summary,
        uint256 amountNeeded,
        uint256 timeNeeded
    ) public onlyMember {
        ProposalCore memory core;
        core.memberTokenId = memberId;
        core.proposalAmountNeeded = amountNeeded;
        core.requestedTimeSpan = timeNeeded;
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

    function completeProposal(uint256 tokenId) public onlyOwner(tokenId) {
        ProjectCore storage core = _projects[tokenId];
        require(
            core.projectState == ProjectState.ASSIGNED,
            "Project must be in an assigned state"
        );
        require(
            core.endWorkPeriod.isExpired(),
            "Work period has not expired"
        );
        core.projectState = ProjectState.COMPLETED;
    }

    function disputeProposal(uint256 tokenId) public onlyOwner(tokenId) {
        ProjectCore storage core = _projects[tokenId];
        require(
            core.projectState == ProjectState.ASSIGNED,
            "Project must be in an assigned state"
        );
        core.projectState = ProjectState.DISPUTED;
    }

    function approveProposal( uint256 projectTokenId, uint256 proposalIndex) public {
        ProjectCore storage core = _projects[projectTokenId];
        require(
            core.projectState == ProjectState.VOTING,
            "Project must be in a voting state"
        );
        require(
            core.voteEnd.isExpired(),
            "Voting period has not expired"
        );
        core.projectState = ProjectState.ASSIGNED;
        core.winningProposalIndex = proposalIndex;
        emit ProposalApproved(projectTokenId, proposalIndex);
    }

    function castVote(uint256 projectTokenId, uint256 proposalIndex) public {
        ProjectCore storage core = _projects[projectTokenId];
        require(core.hasVoted[msg.sender] == false, "Has already voted");
        core.hasVoted[msg.sender] = true;
        _projects[projectTokenId].proposals[proposalIndex].votes += 1;
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

    function projectState(
        uint256 projectTokenId
    ) public view returns (ProjectState) {
        ProjectCore storage project = _projects[projectTokenId];
        return project.projectState;
    }

    function proposalDeadline(
        uint256 projectTokenId
    ) public view returns (uint256) {
        return _projects[projectTokenId].voteEnd.getDeadline();
    }
}
