// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.22;

import "../lib/IERC721.sol";
import "../lib/IERC721Receiver.sol";
import "../lib/IERC721Metadata.sol";
import "../lib/Strings.sol";
import "../lib/ERC165.sol";
import "../lib/Timers.sol";
import "../lib/SafeCast.sol";
import "../lib/Math.sol";
import "../Organizations/Members.sol";
import "./Task.sol";
import "./CrowdFund.sol";


interface IProjectToken is IERC721  {

    function mintProject(
        address owner
    ) external returns (uint256);
 
}

contract ProjectToken is ERC165, IERC721, IERC721Metadata, IProjectToken {

    using Timers for Timers.BlockNumber;
    using SafeCast for uint256;
    using Math for uint256;

    string public _projectMetaURL = "https://www.zini.org/project/";

    string private _name = "Project";
    string private _symbol = "PRJ";

    uint256 public _count = 0;

    mapping(uint256 => address) private _owners;
    mapping(uint256 => address) private _tokenParent;

    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    mapping(address => bool) private _approvedMinters;

    address immutable _boardAddress;

    address immutable _membersAddress;

    address immutable _crowdFundAddress;

    address immutable _taskAddress;

    constructor(address members_) {
        address task = address(new Task(members_, address(this)));
        _taskAddress = task;
        _approvedMinters[task] = true;
        _boardAddress = msg.sender;
        _membersAddress = members_;
        address crowd = address(new CrowdFund(_membersAddress,address(this)));
        _crowdFundAddress = crowd;
        _approvedMinters[crowd] = true;
    }

    modifier onlyMinter() {
        require(
            _approvedMinters[msg.sender],
            "ProjectToken: caller is not a minter"
        );
        _;
    }

    function name () public view virtual returns (string memory) {
        return _name;
    }

    function symbol () public view virtual returns (string memory) {
        return _symbol;
    }

    function getTaskAddress() public view returns (address) {
        return _taskAddress;
    }

    function getBoardAddress() public view returns (address) {
        return _boardAddress;
    }

    function getMembersAddress() public view returns (address) {
        return _membersAddress;
    }

    function getCrowdFundAddress() public view returns (address) {
        return _crowdFundAddress;
    }
     
    function mintProject(address owner) onlyMinter public returns (uint256) {
        _safeMint(owner, _count);
        _tokenParent[_count] = msg.sender;
        _count += 1;
        return _count - 1;
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
        address tokenOwner = ProjectToken.ownerOf(tokenId);
        require(to != tokenOwner, "ERC721: approval to current owner");

        require(
            msg.sender == tokenOwner || isApprovedForAll(tokenOwner, msg.sender),
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
        address tokenOwner,
        address operator
    ) public view virtual override returns (bool) {
        return _operatorApprovals[tokenOwner][operator];
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
        address tokenOwner = ProjectToken.ownerOf(tokenId);
        return (spender == tokenOwner ||
            isApprovedForAll(tokenOwner, spender) ||
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
            ProjectToken.ownerOf(tokenId) == from,
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
        address tokenOwner,
        address operator,
        bool approved
    ) internal virtual {
        require(tokenOwner != operator, "ERC721: approve to caller");
        _operatorApprovals[tokenOwner][operator] = approved;
        emit ApprovalForAll(tokenOwner, operator, approved);
    }

    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ProjectToken.ownerOf(tokenId), to, tokenId);
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
