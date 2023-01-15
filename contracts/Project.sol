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

contract Project is ERC165, IERC721, IERC721Metadata {
    event ProjectCreated(uint256 projectTokenId);
    event Proposal(uint256 projectTokenId, uint256 memberTokenId);

    using Timers for Timers.BlockNumber;
    using SafeCast for uint256;
    using Math for uint256;

    struct ProjectCore {
        uint256 projectTokenId;
        uint256 projectHash;
        Timers.BlockNumber voteStart;
        Timers.BlockNumber voteEnd;
        bool executed;
        bool canceled;
        mapping(address => bool) hasVoted;
        ProposalCore[] proposals;
    }

    struct ProposalCore {
        uint256 memberTokenId;
        uint256 proposalHash;
        uint256 votes;
    }

    enum Funding {
        PRIVATE,
        CROWD_LOAN
    }

    enum Workflow {
        WATERFALL, //noniterative
        AGILE //iterative
    }

    enum ProjectState {
        PENDING,
        ASSIGNED,
        CANCELED,
        COMPLETED,
        ABANDONED
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

    uint256 private _votingDelay = 0;
    uint256 private _votingPeriod = 1000;

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

    ///PROJECT NFT MINT TO STAKEHOLDER

    function mintProject(
        string memory nameP,
        string memory summary,
        Workflow flow,
        Funding funding
    ) public {
        _safeMint(msg.sender, _count);
        uint64 snapshot = block.number.toUint64() + votingDelay().toUint64();
        uint64 deadline = snapshot + votingPeriod().toUint64();
        ProjectCore storage core = _projects[_count];
        core.projectHash = generateProjectHash(nameP, summary, flow, funding);
        core.projectTokenId = _count;
        core.voteStart.setDeadline(snapshot);
        core.voteEnd.setDeadline(deadline);
        _count += 1;
    }

    function updateProjectHash(
        uint256 tokenId,
        string memory nameP,
        string memory summary,
        Workflow flow,
        Funding funding
    ) public {
        address owner = ownerOf(tokenId);
        require(msg.sender == owner, "Only owner of project token can ");
        _projects[tokenId].projectHash = generateProjectHash(
            nameP,
            summary,
            flow,
            funding
        );
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
        string memory summary
    ) public onlyMember {
        ProposalCore memory core;
        core.memberTokenId = memberId;
        core.proposalHash = generateProposalHash(summary, projectId, memberId);
        _projects[projectId].proposals.push(core);
        emit Proposal(projectId, memberId);
    }

    function castVote(uint256 projectTokenId, uint256) public {}

    function proposalVotes(uint256 proposalId) public {}

    function hasVoted(
        uint256 projectTokenId,
        address account
    ) public view returns (bool) {
        return _projects[projectTokenId].hasVoted[account];
    }

    function generateProposalHash(
        string memory projectSummary,
        uint256 projectTokenId,
        uint256 memberTokenId
    ) public pure returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encode(projectSummary, projectTokenId, memberTokenId)
                )
            );
    }

    function projectState(
        uint256 projectTokenId
    ) public view returns (ProjectState) {
        ProjectCore storage project = _projects[projectTokenId];

        if (project.executed) {
            return ProjectState.COMPLETED;
        }

        if (project.canceled) {
            return ProjectState.CANCELED;
        }

        uint256 snapshot = proposalSnapshot(projectTokenId);

        if (snapshot == 0) {
            revert("Governor: unknown proposal id");
        }

        if (snapshot >= block.number) {
            return ProjectState.PENDING;
        }

        uint256 deadline = proposalDeadline(projectTokenId);

        if (deadline >= block.number) {
            return ProjectState.ASSIGNED;
        }

        return ProjectState.ABANDONED;
    }

    function proposalSnapshot(
        uint256 projectTokenId
    ) public view returns (uint256) {
        return _projects[projectTokenId].voteStart.getDeadline();
    }

    function proposalDeadline(
        uint256 projectTokenId
    ) public view returns (uint256) {
        return _projects[projectTokenId].voteEnd.getDeadline();
    }

    function votingDelay() public view returns (uint256) {
        return _votingDelay;
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

    //i need someone to run a advertising campaign with these pictures...

    //this will create a project NFT and the creator will be the owner of the NFT...

    //this NFT will automatically show up on the proposal camp website in the ..

    //anyone with a member nft can propose work on the project and provide a funding estimate and summary of work they shall preform

    //we want bids from members on projects
    //will  change who can vote on bid based on project type

    // -- crowd loan workflow
    // contributors can vote on proposals

    // -- agile project workflow
    // stakeholders must meet with team and refresh the escrow balance each meeting after demonstrating forward momentum
    // in long term goals
    // only NFT holder can vote on proposal

    // -- waterfall workflow with single payor
    // funding goals met before work starts and left in escrow managed by smart contract
    // only nft holder can vote on proposal

    function assignToMember(address member, uint256 proposalId) public {}

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
