// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.17;


import "../lib/Strings.sol";
import "../lib/Timers.sol";
import "../lib/SafeCast.sol";
import "../lib/Math.sol";
import "../Organizations/Members.sol";
import "./ProjectToken.sol";


contract Task {
    event ProjectCreated(uint256 projectTokenId);
    event Proposal( uint256 projectTokenId, uint256 memberTokenId, uint256 proposalId );
    event Dispute(uint256 projectTokenId, string reason);

    using Timers for Timers.BlockNumber;
    using SafeCast for uint256;
    using Math for uint256;

    enum ProjectState {
        PENDING,
        ASSIGNED,
        CANCELED,
        DISPUTED,
        COMPLETED
    }

    struct ProjectCore {
        uint256 projectTokenId;
        uint256 projectHash;
        ProjectState projectState;
        Timers.BlockNumber startWorkPeriod;
        Timers.BlockNumber endWorkPeriod;
        ProposalCore[] proposals;
        uint256 ownerBudgetAmount;
        uint256 winningProposalIndex;
    }

    struct ProposalCore {
        uint256 memberTokenId;
        uint256 proposalHash;
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

    modifier onlyMemberTokenHolder(uint256 tokenId) {
        Members members = Members(_membersAddress);
        require(
            members.ownerOf(tokenId) == msg.sender,
            "Not the member token owner"
        );
        _;
    }

    modifier onlyOwner(uint256 tokenId) {
        require(_projectToken.ownerOf(tokenId) == msg.sender, "Not the token owner");
        _;
    }

    modifier isPending(uint256 tokenId) {
        require(
            _projects[tokenId].projectState == ProjectState.PENDING,
            "Project must be in a pending state"
        );
        _;
    }

    function createProject(
        string memory projectName,
        string memory summary,
        uint256 ownerBudgetAmount
    ) public {
       uint256 tokenId = _projectToken.mintProject(msg.sender);

        ProjectCore storage core = _projects[tokenId];
        core.projectHash = generateProjectHash(projectName, summary);
        core.projectTokenId = tokenId;
        core.projectState = ProjectState.PENDING;
        core.ownerBudgetAmount = ownerBudgetAmount;


        emit ProjectCreated(tokenId);
    }

    function updateProjectHash(
        uint256 tokenId,
        string memory projectName,
        string memory projectSummary
    ) public isPending(tokenId) {
        address owner = _projectToken.ownerOf(tokenId);
        require(msg.sender == owner, "Only owner of project token can update");
        _projects[tokenId].projectHash = generateProjectHash(
            projectName,
            projectSummary
        );
    }

    function updateProjectAmount(
        uint256 tokenId,
        uint256 amount
    ) public isPending(tokenId) {
        address owner = _projectToken.ownerOf(tokenId);
        require(msg.sender == owner, "Only owner of project token can update");
        _projects[tokenId].ownerBudgetAmount = amount;
    }

    function generateProjectHash(
        string memory projectName,
        string memory projectSummary
    ) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(projectName, projectSummary)));
    }

    function createProposal(
        uint256 memberTokenId,
        uint256 projectId,
        string memory summary,
        uint256 amountNeeded,
        uint256 timeNeeded
    ) public onlyMemberTokenHolder(memberTokenId) isPending(projectId) {
        ProposalCore memory core;
        core.memberTokenId = memberTokenId;
        core.proposalAmountNeeded = amountNeeded;
        core.requestedTimeSpan = timeNeeded;
        core.proposalHash = generateProposalHash(summary, projectId, memberTokenId);
        uint256 proposalId = _projects[projectId].proposals.length;
        _projects[projectId].proposals.push(core);
        emit Proposal(projectId, memberTokenId, proposalId);
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
    ) public isPending(projectTokenId) {
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
        ProjectCore storage project = _projects[projectTokenId];
        require(project.winningProposalIndex != proposalIndex, "Cannot cancel winning proposal");
        delete project.proposals[proposalIndex];    
    }

    function completeProposal(uint256 tokenId) public onlyOwner(tokenId) {
        ProjectCore storage core = _projects[tokenId];
        require(
            core.projectState == ProjectState.ASSIGNED,
            "Project must be in an assigned state"
        );
        core.projectState = ProjectState.COMPLETED;
    }

    function disputeProposal(uint256 tokenId, string memory reason) public onlyOwner(tokenId) {
        ProjectCore storage core = _projects[tokenId];
        require(
            core.projectState == ProjectState.ASSIGNED,
            "Project must be in an assigned state"
        );
        core.projectState = ProjectState.DISPUTED;
        emit Dispute(tokenId, reason);
    }

    function approveProposal(
        uint256 projectTokenId,
        uint256 proposalIndex
    ) public isPending(projectTokenId) onlyOwner(projectTokenId) {
        ProjectCore storage core = _projects[projectTokenId];
        uint64 snapshot = block.number.toUint64();
        core.winningProposalIndex = proposalIndex;
        core.projectState = ProjectState.ASSIGNED;
        core.startWorkPeriod.setDeadline(snapshot);
        uint64 requestedTimeSpan = core
            .proposals[proposalIndex]
            .requestedTimeSpan
            .toUint64();
        core.endWorkPeriod.setDeadline(
            snapshot + requestedTimeSpan
        );
        
    }

    function projectState(
        uint256 projectTokenId
    ) public view returns (ProjectState) {
        ProjectCore storage project = _projects[projectTokenId];
        return project.projectState;
    }


}
