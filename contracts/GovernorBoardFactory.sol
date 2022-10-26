// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./GovernorBoard.sol";
import "./Members.sol";
import "./MemberVote.sol";

contract GovernorBoardFactory {
    event BoardCreated(address);
    mapping(address => string) public names;
    mapping(address => bool) public boards;
    address public membersAddress;

    constructor() {
        membersAddress = address(new Members());
    }

    function create(string memory newBoardName) public {
        address boardAddress = address(
            new GovernorBoard(membersAddress, msg.sender)
        );
        names[boardAddress] = newBoardName;
        boards[boardAddress] = true;
        Members f = Members(membersAddress);
        f.mintToFirst(msg.sender, boardAddress);
        emit BoardCreated(boardAddress);
    }

    function isBoard(address whom) public view returns (bool) {
        return boards[whom];
    }
}
