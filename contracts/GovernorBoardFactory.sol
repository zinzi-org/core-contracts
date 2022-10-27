// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./GovernorBoard.sol";
import "./Members.sol";
import "./MemberVote.sol";

contract GovernorBoardFactory {
    event BoardCreated(address);

    mapping(address => bool) public _boards;
    address immutable _membersAddress;

    constructor() {
        _membersAddress = address(new Members());
    }

    function create() public {
        address boardAddress = address(
            new GovernorBoard(_membersAddress, msg.sender)
        );
        _boards[boardAddress] = true;
        Members f = Members(_membersAddress);
        f.mintToFirst(msg.sender, boardAddress);
        emit BoardCreated(boardAddress);
    }

    function isBoard(address whom) public view returns (bool) {
        return _boards[whom];
    }

    function membersAddress() public view returns (address) {
        return _membersAddress;
    }
}
