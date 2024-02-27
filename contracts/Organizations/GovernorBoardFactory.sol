// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./GovernorBoard.sol";
import "./Members.sol";
import "./MemberVote.sol";
import "../Projects/ProjectToken.sol";

contract GovernorBoardFactory {
    event BoardCreated(address);

    mapping(address => bool) public _boards;

    address immutable _membersAddress;

    constructor() {
        _membersAddress = address(new Members());
    }

    function create(string memory name, string memory symbol) public {
        address boardAddress = address(
            new GovernorBoard(_membersAddress, msg.sender, name, symbol)
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
