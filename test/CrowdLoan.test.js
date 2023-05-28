const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect, should } = require("chai");
const { ethers } = require("hardhat");


describe("Crowd Loan Test Cases", () => {

    async function crowdFundFixture() {

        const [...signers] = await ethers.getSigners();

        const boardFactoryFactory = await ethers.getContractFactory("GovernorBoardFactory");
        const factoryContract = await boardFactoryFactory.deploy();
        var membersAddress = await factoryContract.membersAddress();

        const projectTokenFactory = await ethers.getContractFactory("ProjectToken");
        let projectTokenContract = await projectTokenFactory.deploy();
        projectTokenContract = projectTokenContract.connect(signers[0]);

        const crowdFundFactory = await ethers.getContractFactory("CrowdFund");
        let crowdFundContract = await crowdFundFactory.deploy(membersAddress, projectTokenContract.address);

        const membersFactory = await ethers.getContractFactory("Members");
        let membersContract = membersFactory.attach(membersAddress);
        membersContract = membersContract.connect(signers[0]);

        await factoryContract.create("ZinziDAO", "ZZ");

        var usersTokens = await membersContract.getBoards(signers[0].address);
        var boardAddress = await membersContract.getBoardForToken(usersTokens[0]);

        const boardFactory = await ethers.getContractFactory("GovernorBoard");
        let boardContract = boardFactory.attach(boardAddress);
        boardContract = boardContract.connect(signers[0]);

        const memberVotesAddress = boardContract.getMemberVotesAddress();
        const memberVotesFactory = await ethers.getContractFactory("MemberVote");
        let memberVotesContract = memberVotesFactory.attach(memberVotesAddress);
        memberVotesContract = memberVotesContract.connect(signers[0]);

        for (var i = 1; i < signers.length; i++) {
            await boardContract.addMember(signers[i].address);
        }

        return { factoryContract, membersContract, boardContract, memberVotesContract, projectTokenContract, crowdFundContract, signers };
    }
    

    it("can create a board, add a member and create a project", async () => {
        const { factoryContract, membersContract, boardContract, memberVotesContract, projectTokenContract, crowdFundContract, signers } = await loadFixture(crowdFundFixture);


        // var propTx = await crowdFundContract.createProject(
        //     "Run Advertising Campaign",
        //     "I need someone to put a picture of my dog on a big billboard on 3rd steet in Baltimore",
        //     10000000
        //     , { gasLimit: 1000000}
        // );

        // const rcMint = await propTx.wait();
        // const eventMint = rcMint.events.find(event => event.event === "ProjectCreated");
        // const [projectTokenId] = eventMint.args;
       


    });

});
