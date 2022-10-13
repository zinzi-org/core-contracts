const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");

const memberCompiled = require("../artifacts/contracts/Member.sol/Member.json");
const memberBoardCompiled = require("../artifacts/contracts/MemberBoard.sol/MemberBoard.json");


describe("Base Test Setup", () => {

    async function fixture() {
        const [owner, otherAccount] = await ethers.getSigners();

        const BoardFactory = await ethers.getContractFactory("MemberBoardFactory");
        const factory = await BoardFactory.deploy();
        var memberAddress = await factory.memberAddress();
        const memberContract = new ethers.Contract(memberAddress, memberCompiled.abi, owner);

        return { factory, memberContract, owner, otherAccount };
    }

    it('has board member factory with member board', async () => {
        const { factory, memberContract, owner, otherAccount } = await loadFixture(fixture);

        var symbol = await memberContract.symbol();
        expect(symbol).to.equal("MM");

        expect(await factory.create("Harvard MemberBoard")).to.emit(factory, "BoardCreated").withArgs(anyValue);

        var balance = await memberContract.balanceOf(owner.address);
        expect(balance).to.equal(1);

        var obalance = await memberContract.balanceOf(otherAccount.address);
        expect(obalance).to.equal(0);

        var uri = await memberContract.tokenURI(balance);
        expect(uri).to.equal("https://www.zini.org/member/1");

        var groupId = await memberContract.getTokenIdGroupAddress(balance);

        const memberBoard = new ethers.Contract(groupId, memberBoardCompiled.abi, owner);
        expect(memberBoard.address).to.not.be.null;

        var metaURL = await memberBoard._memberMetaURL();
        expect(metaURL).to.equal("https://www.zini.org/member/");

        var isBoardMember = await memberBoard.isBoardMember(owner.address);
        expect(isBoardMember).to.eq(true);
    });

    it('has member nft', async () => {

    });


    it('can create member board', async () => {

    });
});
