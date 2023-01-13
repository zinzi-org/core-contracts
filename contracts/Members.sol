// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/ERC721.sol)
pragma solidity ^0.8.17;

import "./lib/IERC721.sol";
import "./lib/IERC721Receiver.sol";
import "./lib/IERC721Metadata.sol";
import "./GovernorBoardFactory.sol";
import "./GovernorBoard.sol";
import "./lib/Strings.sol";
import "./lib/ERC165.sol";

contract Members is ERC165, IERC721, IERC721Metadata {
    using Strings for uint256;

    string public name = "Member";
    string public symbol = "MM";

    mapping(uint256 => address) private _owners;

    mapping(uint256 => address) private _tokenIndexToBoardAddress;

    mapping(address => mapping(address => bool)) private _memberToGroup;

    mapping(address => uint256[]) private _memberToTokens;
    mapping(uint256 => address) private _tokenIdToMember;
    mapping(address => uint256) private _memberToTokenId;

    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    uint256 public _count = 1;
    address public _boardFactoryAddress;

    constructor() {
        _tokenIdToMember[0] = address(0);
        _boardFactoryAddress = msg.sender;
    }

    function mintToFirst(address who, address boardAddress) public {
        require(
            msg.sender == _boardFactoryAddress,
            "Request must come from board factory"
        );
        _safeMint(who, _count);
        _tokenIdToMember[_count] = who;
        _tokenIndexToBoardAddress[_count] = boardAddress;
        _memberToTokenId[who] = _count;
        _memberToTokens[who].push(_count);
        _memberToGroup[who][boardAddress] = true;
        _count += 1;
    }

    //Can only be called by governor board contract
    function mintTo(address newMember) public {
        require(_memberToGroup[newMember][msg.sender] == false, "Already member of group");
        GovernorBoardFactory x = GovernorBoardFactory(_boardFactoryAddress);
        bool isBoard = x.isBoard(msg.sender);
        require(isBoard, "Not a valid board address");
        _tokenIdToMember[_count] = newMember;
        _memberToTokenId[newMember] = _count;
        _safeMint(newMember, _count);
        _tokenIndexToBoardAddress[_count] = msg.sender;
         _memberToTokens[newMember].push(_count);
        _memberToGroup[newMember][msg.sender] = true;
        _count += 1;
    }


    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function balanceOf(address owner_)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(
            owner_ != address(0),
            "ERC721: address zero is not a valid owner"
        );
        return _balances[owner_];
    }

    function getBoards(address who) public view returns (uint256[] memory){
        return _memberToTokens[who];
    }

    function getBoardForToken(uint256 tokenId) public view returns (address) {
        return _tokenIndexToBoardAddress[tokenId];
    }

    function ownerOf(uint256 tokenId)
        public
        view
        virtual
        override
        returns (address)
    {
        address tokenOwner = _owners[tokenId];
        require(tokenOwner != address(0), "ERC721: invalid token ID");
        return tokenOwner;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        _requireMinted(tokenId);
        address memberBoardAddress = _tokenIndexToBoardAddress[tokenId];
        GovernorBoard memberBoardInstance = GovernorBoard(memberBoardAddress);
        return memberBoardInstance.getTokenURI(tokenId);
    }

    function approve(address to, uint256 tokenId) public virtual override {
        address tokeOwner = Members.ownerOf(tokenId);
        require(to != tokeOwner, "ERC721: approval to current owner");

        require(
            msg.sender == tokeOwner || isApprovedForAll(tokeOwner, msg.sender),
            "ERC721: approve caller is not token owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    function getApproved(uint256 tokenId)
        public
        view
        virtual
        override
        returns (address)
    {
        _requireMinted(tokenId);

        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved)
        public
        virtual
        override
    {
        _setApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address tokeOwner, address operator)
        public
        view
        virtual
        override
        returns (bool)
    {
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

    // - private functions

    // =======================================================================================================================================

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

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId)
        internal
        view
        virtual
        returns (bool)
    {
        address tokeOwner = Members.ownerOf(tokenId);
        return (spender == tokeOwner ||
            isApprovedForAll(tokeOwner, spender) ||
            getApproved(tokenId) == spender);
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

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(
            Members.ownerOf(tokenId) == from,
            "ERC721: transfer from incorrect owner"
        );
        require(to != address(0), "ERC721: transfer to the zero address");

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        _memberToTokenId[to] = _memberToTokenId[from];
        _memberToTokenId[from] = 0;

        _tokenIdToMember[tokenId] = to;

        _memberToTokens[to].push(tokenId);

        address boardAddress = getBoardForToken(tokenId);

        _memberToGroup[from][boardAddress] = false;
        _memberToGroup[to][boardAddress] = true;

        for(uint256 i = 0; i < _memberToTokens[from].length; i++){
            if(_memberToTokens[from][i] == tokenId){
                _memberToTokens[from][i] = _memberToTokens[from][_memberToTokens[from].length - 1];
                _memberToTokens[from].pop();
            }
        }

        emit Transfer(from, to, tokenId);
    }

    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(Members.ownerOf(tokenId), to, tokenId);
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

    function _requireMinted(uint256 tokenId) internal view virtual {
        require(_exists(tokenId), "ERC721: invalid token ID");
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
