const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect, should } = require("chai");
const { ethers } = require("hardhat");


describe("Base Test Cases", () => {

    async function fixture() {

        const [...signers] = await ethers.getSigners();

        const boardFactoryFactory = await ethers.getContractFactory("GovernorBoardFactory");
        const factoryContract = await boardFactoryFactory.deploy();
        var membersAddress = await factoryContract.membersAddress();
        var projectTokenAddress = await factoryContract.projectTokenAddress();

        const projectTokenFactory = await ethers.getContractFactory("ProjectToken");
        let projectTokenContract = await projectTokenFactory.attach(projectTokenAddress);
        projectTokenContract = projectTokenContract.connect(signers[0]);

        const taskFactory = await ethers.getContractFactory("Task");
        let taskContract = await taskFactory.deploy(membersAddress, projectTokenAddress);
        
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

        return { factoryContract, membersContract, boardContract, memberVotesContract, projectTokenContract, taskContract, signers };
    }
    

    // it("can create a board, add a member and create a project", async () => {
    //     const { factoryContract, membersContract, boardContract, memberVotesContract, projectTokenContract, taskContract, signers } = await loadFixture(fixture);

    //     //string memory projectName,
    //     //string memory summary,
    //     //uint256 ownerBudgetAmount
    //     var propTx = await taskContract.populateTransaction.createProject(
    //         "Run Advertising Campaign",
    //         "I need someone to put a picture of my dog on a big billboard on 3rd steet in Baltimore",
    //         10000000
    //     );
    //     let gasEstimate = await ethers.provider.estimateGas(propTx);
    //     propTx.gasLimit = gasEstimate;
    //     let txResponse = await signer[0].sendTransaction(propTx);
    //     const rcMint = await txResponse.wait();
    //     const eventMint = rcMint.events.find(event => event.event === "ProjectCreated");
    //     const [projectTokenId] = eventMint.args;
       
    //     taskContract = taskContract.connect(signers[1]);

    //     var tokenId = await membersContract.getTokenId(signers[1].address);

    //     var proposalTx = await taskContract.populateTransaction.createProposal(
    //         tokenId, 
    //         projectTokenId, 
    //         "I will do this because im smart",
    //         1000,
    //         8000
    //     );
    //     gasEstimate = await ethers.provider.estimateGas(proposalTx);
    //     proposalTx.gasLimit = gasEstimate;
    //     txResponse = await signer[1].sendTransaction(proposalTx);
    //     const rc = await txResponse.wait();
    //     const event = rc.events.find(event => event.event === 'Proposal');
    //     const [proposalId] = event.args;

    //     taskContract = taskContract.connect(signers[0]);
    //     await taskContract.populateTransaction.approveProposal(projectTokenId, proposalId);
    //     gasEstimate = await ethers.provider.estimateGas(proposalTx);
    //     proposalTx.gasLimit = gasEstimate;
    //     txResponse = await signer[0].sendTransaction(proposalTx);
    //     const rc2 = await txResponse.wait();


    //     var state = await taskContract.projectState(projectTokenId);
    //     expect(state).to.equal(2);

    // });

});
