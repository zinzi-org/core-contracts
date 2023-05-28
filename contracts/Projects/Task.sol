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

    enum ProposalState {
        PENDING,
        OWNER_APPROVED,
        APPROVED,
        CANCELED,
        COMPLETED
    }

    struct ProjectCore {
        uint256 projectTokenId;
        uint256 projectHash;
        ProjectState projectState;
        Timers.BlockNumber startWorkPeriod;
        Timers.BlockNumber endWorkPeriod;
        ProposalCore[] proposals;
        uint256 amountFunded;
        uint256 winningProposalIndex;
    }

    struct ProposalCore {
        uint256 memberTokenId;
        uint256 proposalHash;
        uint256 requestedTimeSpan;
        ProposalState proposalState;
    }

    mapping(uint256 => ProjectCore) private _projects;

    uint256 private _balance;

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

    modifier onlyProposer(uint256 projectTokenId, uint256 proposalIndex){
        ProposalCore storage proposal = _projects[projectTokenId].proposals[proposalIndex];
        address proposer = Members(_membersAddress).ownerOf(proposal.memberTokenId);
        require(msg.sender == proposer, "Only proposer can cancel proposal");
        _;
    }

    modifier isPending(uint256 tokenId) {
        require(
            _projects[tokenId].projectState == ProjectState.PENDING,
            "Project must be in a pending state"
        );
        _;
    }

    // --- Project Functions ---

    function createProject(
        string memory projectName,
        string memory summary
    ) public payable {
       uint256 tokenId = _projectToken.mintProject(msg.sender);
        ProjectCore storage core = _projects[tokenId];
        core.projectHash = generateProjectHash(projectName, summary);
        core.projectTokenId = tokenId;
        core.projectState = ProjectState.PENDING;
        core.amountFunded = msg.value;
        _balance += msg.value;
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

    function increaseProjectFunding(
        uint256 projectTokenId
    ) public onlyOwner(projectTokenId) payable {
        require(
            _projects[projectTokenId].projectState == ProjectState.PENDING,
            "Project must be in a pending state"
        );
        _balance += msg.value;
        _projects[projectTokenId].amountFunded += msg.value;
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

    function getProjectDetails(uint256 projectTokenId) public view returns (ProjectCore memory) {
        return _projects[projectTokenId];
    }

    function completeProject(uint256 tokenId) public onlyOwner(tokenId) {
        ProjectCore storage core = _projects[tokenId];
        require(
            core.projectState == ProjectState.ASSIGNED || core.projectState == ProjectState.DISPUTED,
            "Project must be in an assigned or disputed state"
        );
        core.projectState = ProjectState.COMPLETED;
        uint256 proposerTokenId = core.proposals[core.winningProposalIndex].memberTokenId;
        address proposer = Members(_membersAddress).ownerOf(proposerTokenId);
        transferFunds(proposer, core.amountFunded);
    }

    function cancelProject(uint256 tokenId) public onlyOwner(tokenId) {
        ProjectCore storage core = _projects[tokenId];
        require(
            core.projectState == ProjectState.PENDING || core.projectState == ProjectState.DISPUTED,
            "Project must be in a pending or disputed state"
        );
        core.projectState = ProjectState.CANCELED;
        transferFunds(msg.sender, core.amountFunded);
    }

    // --- Proposal Functions ---

    function createProposal(
        uint256 memberTokenId,
        uint256 projectId,
        string memory summary,
        uint256 timeNeeded
    ) public onlyMemberTokenHolder(memberTokenId) isPending(projectId) {
        ProposalCore memory core;
        core.proposalState = ProposalState.PENDING;
        core.memberTokenId = memberTokenId;
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
        uint256 timeNeeded
    ) public onlyProposer(projectTokenId, proposalIndex) isPending(projectTokenId) {
        ProposalCore storage core = _projects[projectTokenId].proposals[
            proposalIndex
        ];
        core.proposalHash = generateProposalHash(
            summary,
            projectTokenId,
            proposalIndex
        );
        core.requestedTimeSpan = timeNeeded;
    }

    function completeProposal(uint256 projectTokenId, uint256 proposalIndex) public  {
        ProjectCore storage project = _projects[projectTokenId];
        require(
            project.projectState == ProjectState.ASSIGNED,
            "Project must be in an assigned state"
        );
        ProposalCore storage proposal = project.proposals[proposalIndex];
        address proposer = Members(_membersAddress).ownerOf(proposal.memberTokenId);
        require(msg.sender == proposer, "Only proposer can complete proposal");
        require(
            proposal.proposalState == ProposalState.APPROVED,
            "Proposal must be in an approved state"
        );
        proposal.proposalState = ProposalState.COMPLETED;
    }

    function cancelProposal(
        uint256 projectTokenId,
        uint256 proposalIndex
    ) public {
        ProjectCore storage project = _projects[projectTokenId];
        require(
            project.projectState == ProjectState.PENDING,
            "Project must be in a pending state"
        );
        ProposalCore storage proposal = project.proposals[proposalIndex];
        address proposer = Members(_membersAddress).ownerOf(proposal.memberTokenId);
        require(msg.sender == proposer, "Only proposer can cancel proposal");
        proposal.proposalState = ProposalState.CANCELED;
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

    function ownerApproveProposal(uint256 projectTokenId, uint256 proposalIndex) public onlyOwner(projectTokenId) isPending(projectTokenId) {
        ProjectCore storage core = _projects[projectTokenId];
        ProposalCore storage proposal = core.proposals[proposalIndex];
        proposal.proposalState = ProposalState.OWNER_APPROVED;
    }

    function approveProposal(
        uint256 projectTokenId,
        uint256 proposalIndex
    ) public isPending(projectTokenId) onlyProposer(projectTokenId, proposalIndex) {
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
        core.proposals[proposalIndex].proposalState = ProposalState.APPROVED; 
    }

    function getProposalDetails(uint256 projectTokenId, uint256 proposalIndex) public view returns (ProposalCore memory) {
        return _projects[projectTokenId].proposals[proposalIndex];
    }


    // --- Utility Functions ---

    function transferFunds(address recipient, uint256 amount) private {
        require(address(this).balance >= amount, "Not enough balance");
        require(_balance >= amount, "Not enough _balance");
        
        // If checks pass, proceed with the transfer
        payable(recipient).transfer(amount);
        
        // Then, update the balance
        _balance -= amount;
    }

    function getTotalBalance() public view returns (uint256) {
        return _balance;
    }


}
