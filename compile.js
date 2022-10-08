const path = require("path");
const fs = require('fs-extra');
const solc = require("solc");
const { Console } = require("console");


const noDelegate = path.resolve(__dirname, "contracts/lib", "NoDelegateCall.sol");
const noDelegateSource = fs.readFileSync(noDelegate, "utf8");

const stringsPath = path.resolve(__dirname, "contracts/lib", "Strings.sol");
const stringsSource = fs.readFileSync(stringsPath, "utf8");

const ERC165Path = path.resolve(__dirname, "contracts/lib", "ERC165.sol");
const ERC165PathSource = fs.readFileSync(ERC165Path, "utf8");

const IERC165Path = path.resolve(__dirname, "contracts/lib", "IERC165.sol");
const IERC165PathSource = fs.readFileSync(IERC165Path, "utf8");

const IERC721Path = path.resolve(__dirname, "contracts/lib", "IERC721.sol");
const IERC721PathSource = fs.readFileSync(IERC721Path, "utf8");

const IERC721MetaDataPath = path.resolve(__dirname, "contracts/lib", "IERC721MetaData.sol");
const IERC721MetaDataPathSource = fs.readFileSync(IERC721MetaDataPath, "utf8");

const IERC721ReceiverPath = path.resolve(__dirname, "contracts/lib", "IERC721Receiver.sol");
const IERC721ReceiverPathSource = fs.readFileSync(IERC721ReceiverPath, "utf8");

const memberBoardFactoryPath = path.resolve(__dirname, "contracts", "MemberBoardFactory.sol");
const memberBoardFactorySource = fs.readFileSync(memberBoardFactoryPath, "utf8");

const memberBoardPath = path.resolve(__dirname, "contracts", "MemberBoard.sol");
const memberBoardSource = fs.readFileSync(memberBoardPath, "utf8");

const memberNFTPath = path.resolve(__dirname, "contracts", "MemberNFT.sol");
const memberNFTSource = fs.readFileSync(memberNFTPath, "utf8");

const projectFactoryPath = path.resolve(__dirname, "contracts", "ProjectFactory.sol");
const projectFactorySource = fs.readFileSync(projectFactoryPath, "utf8");

const projectPath = path.resolve(__dirname, "contracts", "Project.sol");
const projectSource = fs.readFileSync(projectPath, "utf8");

const proposalNFTPath = path.resolve(__dirname, "contracts", "ProposalNFT.sol");
const proposalNFTSource = fs.readFileSync(proposalNFTPath, "utf8");



var input = {
    language: 'Solidity',
    sources: {
        'MemberBoardFactory.sol': {
            content: memberBoardFactorySource
        },
        'MemberBoard.sol': {
            content: memberBoardSource
        },
        'MemberNFT.sol': {
            content: memberNFTSource
        },
        'ProjectFactory.sol': {
            content: projectFactorySource
        },
        'Project.sol': {
            content: projectSource
        },
        'ProposalNFT.sol': {
            content: proposalNFTSource
        }
    },
    settings: {
        outputSelection: {
            '*': {
                '*': ['*']
            }
        }
    }
};


const buildPath = path.resolve(__dirname, 'build');
fs.removeSync(buildPath);


function findImports(path) {
    if (path === "lib/NoDelegateCall.sol") return { contents: `${noDelegateSource}` };
    if (path === "MemberBoardFactory.sol") return { contents: `${memberBoardFactorySource}` };
    if (path === "MemberBoard.sol") return { contents: `${memberBoardSource}` };
    if (path === "MemberNFT.sol") return { contents: `${memberNFTSource}` };
    if (path === "ProjectFactory.sol") return { contents: `${projectFactorySource}` };
    if (path === "Project.sol") return { contents: `${projectSource}` };
    if (path === "ProposalNFT.sol") return { contents: `${proposalNFTSource}` };

    if (path === "lib/ERC165.sol") return { contents: `${ERC165PathSource}` };
    if (path === "lib/IERC165.sol") return { contents: `${IERC165PathSource}` };
    if (path === "lib/IERC721.sol") return { contents: `${IERC721PathSource}` };
    if (path === "lib/IERC721Metadata.sol") return { contents: `${IERC721MetaDataPathSource}` };
    if (path === "lib/IERC721Receiver.sol") return { contents: `${IERC721ReceiverPathSource}` };
    if (path === "lib/NoDelegateCall.sol") return { contents: `${noDelegateSource}` };
    if (path === "lib/Strings.sol") return { contents: `${stringsSource}` };
    else return { error: "File not found" };
}

let output = JSON.parse(solc.compile(JSON.stringify(input), { import: findImports }));


if (output.errors) {
    console.log("++++++++++++++++++++++++++++++++++++++++++++++++++++++ERRORS++++++++++++++++++++++++++++++++++++++++++++++++++++++");
    for (var i = 0; i < output.errors.length; i++) {
        console.log(output.errors[i].formattedMessage);
    }
    console.log("++++++++++++++++++++++++++++++++++++++++++++++++++++++ERRORS++++++++++++++++++++++++++++++++++++++++++++++++++++++");
    return;
}

fs.ensureDirSync(buildPath);

for (let contract in output.contracts["MemberBoardFactory.sol"]) {
    fs.outputJsonSync(
        path.resolve(buildPath, contract.replace(':', '') + '.json'),
        output.contracts["MemberBoardFactory.sol"][contract]
    );
}

for (let contract in output.contracts["MemberBoard.sol"]) {
    fs.outputJsonSync(
        path.resolve(buildPath, contract.replace(':', '') + '.json'),
        output.contracts["MemberBoard.sol"][contract]
    );
}

for (let contract in output.contracts["MemberNFT.sol"]) {
    fs.outputJsonSync(
        path.resolve(buildPath, contract.replace(':', '') + '.json'),
        output.contracts["MemberNFT.sol"][contract]
    );
}


for (let contract in output.contracts["ProjectFactory.sol"]) {
    fs.outputJsonSync(
        path.resolve(buildPath, contract.replace(':', '') + '.json'),
        output.contracts["ProjectFactory.sol"][contract]
    );
}

for (let contract in output.contracts["Project.sol"]) {
    fs.outputJsonSync(
        path.resolve(buildPath, contract.replace(':', '') + '.json'),
        output.contracts["Project.sol"][contract]
    );
}

for (let contract in output.contracts["ProposalNFT.sol"]) {
    fs.outputJsonSync(
        path.resolve(buildPath, contract.replace(':', '') + '.json'),
        output.contracts["ProposalNFT.sol"][contract]
    );
}





console.log("Build compile complete!");