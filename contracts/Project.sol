// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.17;

import "./lib/IERC721.sol";
import "./lib/IERC721Receiver.sol";
import "./lib/IERC721Metadata.sol";
import "./lib/Strings.sol";
import "./lib/ERC165.sol";
import "./lib/Timers.sol";
import "./lib/SafeCast.sol";
import "./lib/Math.sol";
import "./Members.sol";

interface IProject {
    enum Workflow {
        WATERFALL, //noniterative
        AGILE //iterative
    }

    enum Funding {
        PRIVATE,
        CROWD_LOAN
    }

    enum ProjectState {
        VOTING,
        FUNDING,
        ASSIGNED,
        CANCELED,
        DISPUTED,
        COMPLETED
    }

    function mintProject(
        string memory nameP,
        string memory summary,
        Workflow flow,
        Funding funding,
        uint256 ownerBudgetAmount
    ) external;

    function updateProjectHash(
        uint256 tokenId,
        string memory nameP,
        string memory summary,
        Workflow flow,
        Funding funding
    ) external;

    function updateProjectAmount(uint256 tokenId, uint256 amount) external;

    function generateProjectHash(
        string memory nameP,
        string memory summary,
        Workflow flow,
        Funding funding
    ) external pure returns (uint256);
}

contract Project is ERC165, IERC721, IERC721Metadata, IProject {
    event ProjectCreated(uint256 projectTokenId);
    event Proposal(
        uint256 projectTokenId,
        uint256 memberTokenId,
        uint256 proposalId
    );

    using Timers for Timers.BlockNumber;
    using SafeCast for uint256;
    using Math for uint256;

    struct ProjectCore {
        uint256 projectTokenId;
        uint256 projectHash;
        Funding funding;
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

    string public _projectMetaURL = "https://www.zini.org/project/";

    string public name = "Project";
    string public symbol = "PRJ";

    uint256 public _count = 0;

    mapping(uint256 => uint256) tokenIdToProposalFee;

    mapping(uint256 => address) private _owners;
    mapping(uint256 => address) private _memberAssignment;

    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    mapping(uint256 => ProjectCore) private _projects;

    address private _membersAddress;

    uint256 private _votingPeriod = 1000;

    mapping(uint256 => uint256) private _projectOwnerBalance;
    mapping(uint256 => uint256) private _proposalOwnerBalance;

    constructor(address membersAddress) {
        _membersAddress = membersAddress;
    }

    modifier onlyMember() {
        Members members = Members(_membersAddress);
        require(members.balanceOf(msg.sender) > 0, "Not a member");
        _;
    }

    modifier onlyOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, "Not the token owner");
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
        Workflow flow,
        Funding funding,
        uint256 ownerBudgetAmount
    ) public {
        _safeMint(msg.sender, _count);
        uint64 deadline = block.number.toUint64() + votingPeriod().toUint64();
        ProjectCore storage core = _projects[_count];
        core.funding = funding;
        core.projectHash = generateProjectHash(nameP, summary, flow, funding);
        core.projectTokenId = _count;
        core.projectState = ProjectState.VOTING;
        core.voteEnd.setDeadline(deadline);
        core.ownerBudgetAmount = ownerBudgetAmount;
        _count += 1;
        emit ProjectCreated(core.projectTokenId);
    }

    function updateProjectHash(
        uint256 tokenId,
        string memory nameP,
        string memory summary,
        Workflow flow,
        Funding funding
    ) public isVoting(tokenId) {
        address owner = ownerOf(tokenId);
        require(msg.sender == owner, "Only owner of project token can ");
        _projects[tokenId].projectHash = generateProjectHash(
            nameP,
            summary,
            flow,
            funding
        );
    }

    function updateProjectAmount(
        uint256 tokenId,
        uint256 amount
    ) public isVoting(tokenId) {
        address owner = ownerOf(tokenId);
        require(msg.sender == owner, "Only owner of project token can ");
        _projects[tokenId].ownerBudgetAmount = amount;
    }

    function generateProjectHash(
        string memory nameP,
        string memory summary,
        Workflow flow,
        Funding funding
    ) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(nameP, summary, flow, funding)));
    }

    ///MEMBER NFT Proposals for Project Ownership which will be approved via stakeholders.
    // ---------------------------------------------

    ///Only members can submit proposals.. they must provide a member Token Id and a proposal Hash to a specific Project Token.
    ///Stakeholders can vote on bids from members on their projects.

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

    //Require funds in escrow?
    //Project does not need escrow until a bid is selected. The member bid will tell the owner how much money
    //is needed in escrow to allow the project to enter the "ASSIGNED" state.

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

    function completeProposal(uint256 tokenId) public onlyOwner(tokenId) {}

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

        if (core.funding == Funding.PRIVATE) {
            address owner = ownerOf(projectTokenId);
            require(
                msg.sender == owner,
                "Only owner of project can approve prop"
            );
            if (_projects[projectTokenId].proposals[proposalIndex].votes > 0) {
                uint64 snapshot = block.number.toUint64();
                _projects[projectTokenId].winningProposalIndex = proposalIndex;
                _projects[projectTokenId].projectState = ProjectState.ASSIGNED;
                _projects[projectTokenId].startWorkPeriod.setDeadline(snapshot);
                uint64 requestedTimeSpan = _projects[projectTokenId]
                    .proposals[proposalIndex]
                    .requestedTimeSpan
                    .toUint64();
                _projects[projectTokenId].endWorkPeriod.setDeadline(
                    snapshot + requestedTimeSpan
                );
            }
        } else {
            //TODO IMPLEMENT CROWD LOAN APPROVAL
            //Can only approve proposal if it has the majority of votes
            //and the proposal has enough funding for people that have voted
            //and enough time has been given for people to vote
            //and the project is in the voting state
            //and the project has not already been assigned
            //and the project has not already been disputed
            //and the project has not already been completed
            //and the project has not already been cancelled
            //and the project has not already been refunded
        }
    }

    function castVote(uint256 projectTokenId, uint256 proposalIndex) public {
        ProjectCore storage core = _projects[projectTokenId];
        require(core.hasVoted[msg.sender] == false, "Has already voted");
        if (core.funding == Funding.PRIVATE) {
            address owner = ownerOf(projectTokenId);
            require(
                msg.sender == owner,
                "Must be the owner of the project token"
            );
        }
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
        // VOTING,
        // FUNDING,
        // ASSIGNED,
        // CANCELED,
        // DISPUTED,
        // COMPLETED
        return project.projectState;
    }

    function proposalDeadline(
        uint256 projectTokenId
    ) public view returns (uint256) {
        return _projects[projectTokenId].voteEnd.getDeadline();
    }

    function votingPeriod() public view returns (uint256) {
        return _votingPeriod;
    }

    function setProposalFee(
        uint256 newFee,
        uint256 tokenId
    ) public onlyOwner(tokenId) {
        tokenIdToProposalFee[tokenId] = newFee;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function balanceOf(
        address owner_
    ) public view virtual override returns (uint256) {
        require(
            owner_ != address(0),
            "ERC721: address zero is not a valid owner"
        );
        return _balances[owner_];
    }

    function ownerOf(
        uint256 tokenId
    ) public view virtual override returns (address) {
        address tokenOwner = _owners[tokenId];
        require(tokenOwner != address(0), "ERC721: invalid token ID");
        return tokenOwner;
    }

    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        _requireMinted(tokenId);
        return string.concat(_projectMetaURL, Strings.toString(tokenId));
    }

    function approve(address to, uint256 tokenId) public virtual override {
        address tokeOwner = Project.ownerOf(tokenId);
        require(to != tokeOwner, "ERC721: approval to current owner");

        require(
            msg.sender == tokeOwner || isApprovedForAll(tokeOwner, msg.sender),
            "ERC721: approve caller is not token owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    function getApproved(
        uint256 tokenId
    ) public view virtual override returns (address) {
        _requireMinted(tokenId);

        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(
        address operator,
        bool approved
    ) public virtual override {
        _setApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(
        address tokeOwner,
        address operator
    ) public view virtual override returns (bool) {
        return _operatorApprovals[tokeOwner][operator];
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "ERC721: caller is not token owner nor approved"
        );

        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override {
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "ERC721: caller is not token owner nor approved"
        );
        _safeTransfer(from, to, tokenId, data);
    }

    function _isApprovedOrOwner(
        address spender,
        uint256 tokenId
    ) internal view virtual returns (bool) {
        address tokeOwner = Project.ownerOf(tokenId);
        return (spender == tokeOwner ||
            isApprovedForAll(tokeOwner, spender) ||
            getApproved(tokenId) == spender);
    }

    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(
            _checkOnERC721Received(from, to, tokenId, data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(
            Project.ownerOf(tokenId) == from,
            "ERC721: transfer from incorrect owner"
        );
        require(to != address(0), "ERC721: transfer to the zero address");

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function _setApprovalForAll(
        address tokeOwner,
        address operator,
        bool approved
    ) internal virtual {
        require(tokeOwner != operator, "ERC721: approve to caller");
        _operatorApprovals[tokeOwner][operator] = approved;
        emit ApprovalForAll(tokeOwner, operator, approved);
    }

    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(Project.ownerOf(tokenId), to, tokenId);
    }

    function _requireMinted(uint256 tokenId) internal view virtual {
        require(_exists(tokenId), "ERC721: invalid token ID");
    }

    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");
        _balances[to] += 1;
        _owners[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.code.length > 0) {
            try
                IERC721Receiver(to).onERC721Received(
                    msg.sender,
                    from,
                    tokenId,
                    data
                )
            returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert(
                        "ERC721: transfer to non ERC721Receiver implementer"
                    );
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }
}
