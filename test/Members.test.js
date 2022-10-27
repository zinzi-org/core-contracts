const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");

const memberCompiled = require("../artifacts/contracts/Members.sol/Members.json");
const memberBoardCompiled = require("../artifacts/contracts/GovernorBoard.sol/GovernorBoard.json");
const memberVotesCompiled = require("../artifacts/contracts/MemberVote.sol/MemberVote.json");

describe("Base Test Setup", () => {

    async function fixture() {
        const [owner, otherAccount] = await ethers.getSigners();
        const BoardFactory = await ethers.getContractFactory("GovernorBoardFactory");
        const factory = await BoardFactory.deploy();
        var memberAddress = await factory.membersAddress();
        const memberContract = new ethers.Contract(memberAddress, memberCompiled.abi, owner);
        const memberVotesAddress = memberContract.get
        const memberVotes = new ethers.Contract(memberVotesAddress, memberVotesCompiled.abi, owner);

        return { factory, memberContract, owner, otherAccount, memberVotes };
    }

    it('has board member factory with member board', async () => {
        const { factory, memberContract, owner, otherAccount } = await loadFixture(fixture);

        var symbol = await memberContract.symbol();
        expect(symbol).to.equal("MM");

        expect(await factory.create()).to.emit(factory, "BoardCreated").withArgs(anyValue);

        var balance = await memberContract.balanceOf(owner.address);
        expect(balance).to.equal(1);

        var obalance = await memberContract.balanceOf(otherAccount.address);
        expect(obalance).to.equal(0);

        var uri = await memberContract.tokenURI(balance);
        expect(uri).to.equal("https://www.zini.org/member/1");

        var groupId = await memberContract.getTokenGroup(balance);

        const memberBoard = new ethers.Contract(groupId, memberBoardCompiled.abi, owner);
        expect(memberBoard.address).to.not.be.null;

        var metaURL = await memberBoard._memberMetaURL();
        expect(metaURL).to.equal("https://www.zini.org/member/");

        var isBoardMember = await memberBoard.isGovernor(owner.address);
        expect(isBoardMember).to.eq(true);
    });

    it('can add member to group', async () => {
        const { factory, memberContract, owner, otherAccount } = await loadFixture(fixture);
        await factory.create();
        var balance = await memberContract.balanceOf(owner.address);
        var groupId = await memberContract.getTokenGroup(balance);
        const memberBoard = new ethers.Contract(groupId, memberBoardCompiled.abi, owner);
        await memberContract.mintTo(otherAccount.address, groupId);
        var obalance = await memberContract.balanceOf(otherAccount.address);
        expect(obalance).to.equal(1);
    });

    it('can add member to group', async () => {
        const { factory, memberContract, owner, otherAccount } = await loadFixture(fixture);
        await factory.create();
        var balance = await memberContract.balanceOf(owner.address);
        var groupId = await memberContract.getTokenGroup(balance);
        const memberBoard = new ethers.Contract(groupId, memberBoardCompiled.abi, owner);
        await memberContract.mintTo(otherAccount.address, groupId);
        var obalance = await memberContract.balanceOf(otherAccount.address);
        expect(obalance).to.equal(1);
    });

    it('governor can create proposal', async () => {
        const { factory, memberContract, owner, otherAccount } = await loadFixture(fixture);
        await factory.create();
        var balance = await memberContract.balanceOf(owner.address);
        var groupId = await memberContract.getTokenGroup(balance);
        const memberBoard = new ethers.Contract(groupId, memberBoardCompiled.abi, owner);
        await memberContract.mintTo(otherAccount.address, groupId);
    });


});
