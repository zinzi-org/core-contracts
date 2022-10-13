// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./MemberBoard.sol";
import "./Member.sol";

contract MemberBoardFactory {
    event BoardCreated(address);
    mapping(address => string) public names;
    mapping(address => bool) public boards;
    address public memberAddress;

    constructor() {
        memberAddress = address(new Member());
    }

    function create(string memory newBoardName) public {
        address boardAddress = address(new MemberBoard(memberAddress, msg.sender));
        names[boardAddress] = newBoardName;
        boards[boardAddress] = true;
        Member f = Member(memberAddress);
        f.mintToFirst(msg.sender, boardAddress);
        emit BoardCreated(boardAddress);
    }

    function isBoard(address whom) public view returns (bool) {
        return boards[whom];
    }
}
