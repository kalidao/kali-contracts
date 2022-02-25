const { BigNumber } = require("ethers")
const chai = require("chai")
const { expect } = require("chai")

const wethAddress = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"

chai.should()

// Defaults to e18 using amount * 10^18
function getBigNumber(amount, decimals = 18) {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(decimals))
}

async function advanceTime(time) {
  await ethers.provider.send("evm_increaseTime", [time])
}

describe("Crowdsale", function () {
    let Kali // KaliDAO contract
    let kali // KaliDAO contract instance
    let PurchaseToken // PurchaseToken contract
    let purchaseToken // PurchaseToken contract instance
    let Whitelist // Whitelist contract
    let whitelist // Whitelist contract instance
    let Crowdsale // Crowdsale contract
    let crowdsale // Crowdsale contract instance
    let proposer // signerA
    let alice // signerB
    let bob // signerC
  
    beforeEach(async () => {
      ;[proposer, alice, bob] = await ethers.getSigners()
  
      Kali = await ethers.getContractFactory("KaliDAO")
      kali = await Kali.deploy()
      await kali.deployed()

      PurchaseToken = await ethers.getContractFactory("KaliERC20")
      purchaseToken = await PurchaseToken.deploy()
      await purchaseToken.deployed()
      await purchaseToken.init(
        "KALI",
        "KALI",
        "DOCS",
        [proposer.address],
        [getBigNumber(1000)],
        false,
        proposer.address
      )

      Whitelist = await ethers.getContractFactory("KaliAccessManager")
      whitelist = await Whitelist.deploy()
      await whitelist.deployed()
      
      Crowdsale = await ethers.getContractFactory("KaliDAOcrowdsale")
      crowdsale = await Crowdsale.deploy(whitelist.address, wethAddress)
      await crowdsale.deployed()
    })
  
    it("Should allow unrestricted ETH crowdsale", async function () {
        // Instantiate KaliDAO
        await kali.init(
          "KALI",
          "KALI",
          "DOCS",
          false,
          [],
          [],
          [proposer.address],
          [getBigNumber(10)],
          [30, 0, 0, 60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        )

        // Set up payload for extension proposal
        let payload = ethers.utils.defaultAbiCoder.encode(
            ["uint256", "address", "uint8", "uint96", "uint32", "string"],
                [
                    0,
                    "0x0000000000000000000000000000000000000000",
                    2,
                    getBigNumber(200),
                    1672174799,
                    "DOCS"
                ]
        )

        await kali.propose(9, "TEST", [crowdsale.address], [1], [payload])
        await kali.vote(1, true)
        await advanceTime(35)
        await kali.processProposal(1)
        await crowdsale 
            .callExtension(kali.address, getBigNumber(50), {
                value: getBigNumber(50),
        })
        await crowdsale 
            .connect(alice)
            .callExtension(kali.address, getBigNumber(50), {
                value: getBigNumber(50),
        })
        expect(await ethers.provider.getBalance(kali.address)).to.equal(
            getBigNumber(100)
        )
        expect(await kali.balanceOf(proposer.address)).to.equal(getBigNumber(110))
        expect(await kali.balanceOf(alice.address)).to.equal(getBigNumber(100))
    })

    it("Should allow restricted ETH crowdsale", async function () {
        // Instantiate KaliDAO
        await kali.init(
          "KALI",
          "KALI",
          "DOCS",
          false,
          [],
          [],
          [proposer.address],
          [getBigNumber(10)],
          [30, 0, 0, 60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        )

        // Set up whitelist
        await whitelist.createList(
            [proposer.address, alice.address],
            "0x074b43252ffb4a469154df5fb7fe4ecce30953ba8b7095fe1e006185f017ad10"
        )

        // Set up payload for extension proposal
        let payload = ethers.utils.defaultAbiCoder.encode(
            ["uint256", "address", "uint8", "uint96", "uint32", "string"],
                [
                    1,
                    "0x0000000000000000000000000000000000000000",
                    2,
                    getBigNumber(200),
                    1672174799,
                    "DOCS"
                ]
        )

        await kali.propose(9, "TEST", [crowdsale.address], [1], [payload])
        await kali.vote(1, true)
        await advanceTime(35)
        await kali.processProposal(1)
        await crowdsale 
            .callExtension(kali.address, getBigNumber(50), {
                value: getBigNumber(50),
        })
        await crowdsale 
            .connect(alice)
            .callExtension(kali.address, getBigNumber(50), {
                value: getBigNumber(50),
        })
        expect(await ethers.provider.getBalance(kali.address)).to.equal(
            getBigNumber(100)
        )
        expect(await kali.balanceOf(proposer.address)).to.equal(getBigNumber(110))
        expect(await kali.balanceOf(alice.address)).to.equal(getBigNumber(100))
    })

    it("Should forbid non-whitelisted participation in ETH crowdsale", async function () {
        // Instantiate KaliDAO
        await kali.init(
          "KALI",
          "KALI",
          "DOCS",
          false,
          [],
          [],
          [proposer.address],
          [getBigNumber(10)],
          [30, 0, 0, 60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        )

        // Set up whitelist
        await whitelist.createList(
            [proposer.address],
            "0x074b43252ffb4a469154df5fb7fe4ecce30953ba8b7095fe1e006185f017ad10"
        )

        // Set up payload for extension proposal
        let payload = ethers.utils.defaultAbiCoder.encode(
            ["uint256", "address", "uint8", "uint96", "uint32", "string"],
                [
                    1,
                    "0x0000000000000000000000000000000000000000",
                    2,
                    getBigNumber(200),
                    1672174799,
                    "DOCS"
                ]
        )

        await kali.propose(9, "TEST", [crowdsale.address], [1], [payload])
        await kali.vote(1, true)
        await advanceTime(35)
        await kali.processProposal(1)
        await crowdsale 
            .callExtension(kali.address, getBigNumber(50), {
                value: getBigNumber(50),
        })
        expect(await crowdsale 
            .connect(alice)
            .callExtension(kali.address, getBigNumber(50), {
                value: getBigNumber(50),
        }).should.be.reverted)
        expect(await ethers.provider.getBalance(kali.address)).to.equal(
            getBigNumber(50)
        )
        expect(await kali.balanceOf(proposer.address)).to.equal(getBigNumber(110))
        expect(await kali.balanceOf(alice.address)).to.equal(getBigNumber(0))
    })

    it("Should enforce purchase limit in ETH crowdsale", async function () {
        // Instantiate KaliDAO
        await kali.init(
          "KALI",
          "KALI",
          "DOCS",
          false,
          [],
          [],
          [proposer.address],
          [getBigNumber(10)],
          [30, 0, 0, 60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        )

        // Set up whitelist
        await whitelist.createList(
            [proposer.address],
            "0x074b43252ffb4a469154df5fb7fe4ecce30953ba8b7095fe1e006185f017ad10"
        )

        // Set up payload for extension proposal
        let payload = ethers.utils.defaultAbiCoder.encode(
            ["uint256", "address", "uint8", "uint96", "uint32", "string"],
                [
                    1,
                    "0x0000000000000000000000000000000000000000",
                    2,
                    getBigNumber(200),
                    1672174799,
                    "DOCS"
                ]
        )

        await kali.propose(9, "TEST", [crowdsale.address], [1], [payload])
        await kali.vote(1, true)
        await advanceTime(35)
        await kali.processProposal(1)
        await crowdsale 
            .callExtension(kali.address, getBigNumber(50), {
                value: getBigNumber(50),
        })
        await crowdsale 
            .callExtension(kali.address, getBigNumber(50), {
                value: getBigNumber(50),
        })
        expect(await crowdsale 
            .callExtension(kali.address, getBigNumber(50), {
                value: getBigNumber(50),
        }).should.be.reverted)
        expect(await ethers.provider.getBalance(kali.address)).to.equal(
            getBigNumber(100)
        )
        expect(await kali.balanceOf(proposer.address)).to.equal(getBigNumber(210))
    })

    it("Should allow unrestricted ERC20 crowdsale", async function () {
        // Instantiate KaliDAO
        await kali.init(
          "KALI",
          "KALI",
          "DOCS",
          false,
          [],
          [],
          [proposer.address],
          [getBigNumber(10)],
          [30, 0, 0, 60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        )

        await purchaseToken.approve(crowdsale.address, getBigNumber(50))

        // Set up payload for extension proposal
        let payload = ethers.utils.defaultAbiCoder.encode(
            ["uint256", "address", "uint8", "uint96", "uint32", "string"],
                [
                    0,
                    purchaseToken.address,
                    2,
                    getBigNumber(200),
                    1672174799,
                    "DOCS"
                ]
        )

        await kali.propose(9, "TEST", [crowdsale.address], [1], [payload])
        await kali.vote(1, true)
        await advanceTime(35)
        await kali.processProposal(1)
        await crowdsale.callExtension(kali.address, getBigNumber(50))
        expect(await purchaseToken.balanceOf(proposer.address)).to.equal(
            getBigNumber(950)
        )
        expect(await purchaseToken.balanceOf(kali.address)).to.equal(
            getBigNumber(50)
        )
        expect(await kali.balanceOf(proposer.address)).to.equal(getBigNumber(110))
    })

    it("Should allow restricted ERC20 crowdsale", async function () {
        // Instantiate KaliDAO
        await kali.init(
          "KALI",
          "KALI",
          "DOCS",
          false,
          [],
          [],
          [proposer.address],
          [getBigNumber(10)],
          [30, 0, 0, 60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        )

        await purchaseToken.approve(crowdsale.address, getBigNumber(50))

        // Set up whitelist
        await whitelist.createList(
            [proposer.address],
            "0x074b43252ffb4a469154df5fb7fe4ecce30953ba8b7095fe1e006185f017ad10"
        )

        // Set up payload for extension proposal
        let payload = ethers.utils.defaultAbiCoder.encode(
            ["uint256", "address", "uint8", "uint96", "uint32", "string"],
                [
                    1,
                    purchaseToken.address,
                    2,
                    getBigNumber(200),
                    1672174799,
                    "DOCS"
                ]
        )

        await kali.propose(9, "TEST", [crowdsale.address], [1], [payload])
        await kali.vote(1, true)
        await advanceTime(35)
        await kali.processProposal(1)
        await crowdsale.callExtension(kali.address, getBigNumber(50))
        expect(await purchaseToken.balanceOf(proposer.address)).to.equal(
            getBigNumber(950)
        )
        expect(await purchaseToken.balanceOf(kali.address)).to.equal(
            getBigNumber(50)
        )
        expect(await kali.balanceOf(proposer.address)).to.equal(getBigNumber(110))
    })

    it("Should forbid non-whitelisted participation in ERC20 crowdsale", async function () {
        // Instantiate KaliDAO
        await kali.init(
          "KALI",
          "KALI",
          "DOCS",
          false,
          [],
          [],
          [proposer.address],
          [getBigNumber(10)],
          [30, 0, 0, 60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        )

        await purchaseToken.approve(crowdsale.address, getBigNumber(50))

        // Set up whitelist
        await whitelist.createList(
            [alice.address],
            "0x074b43252ffb4a469154df5fb7fe4ecce30953ba8b7095fe1e006185f017ad10"
        )

        // Set up payload for extension proposal
        let payload = ethers.utils.defaultAbiCoder.encode(
            ["uint256", "address", "uint8", "uint96", "uint32", "string"],
                [
                    1,
                    purchaseToken.address,
                    2,
                    getBigNumber(200),
                    1672174799,
                    "DOCS"
                ]
        )

        await kali.propose(9, "TEST", [crowdsale.address], [1], [payload])
        await kali.vote(1, true)
        await advanceTime(35)
        await kali.processProposal(1)
        expect(await crowdsale.callExtension(kali.address, getBigNumber(50)).should.be.reverted)
        expect(await purchaseToken.balanceOf(proposer.address)).to.equal(
            getBigNumber(1000)
        )
        expect(await purchaseToken.balanceOf(kali.address)).to.equal(
            getBigNumber(0)
        )
        expect(await kali.balanceOf(proposer.address)).to.equal(getBigNumber(10))
    })

    it("Should enforce purchase limit in ERC20 crowdsale", async function () {
        // Instantiate KaliDAO
        await kali.init(
          "KALI",
          "KALI",
          "DOCS",
          false,
          [],
          [],
          [proposer.address],
          [getBigNumber(10)],
          [30, 0, 0, 60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        )

        await purchaseToken.approve(crowdsale.address, getBigNumber(500))

        // Set up whitelist
        await whitelist.createList(
            [proposer.address],
            "0x074b43252ffb4a469154df5fb7fe4ecce30953ba8b7095fe1e006185f017ad10"
        )

        // Set up payload for extension proposal
        let payload = ethers.utils.defaultAbiCoder.encode(
            ["uint256", "address", "uint8", "uint96", "uint32", "string"],
                [
                    1,
                    purchaseToken.address,
                    2,
                    getBigNumber(200),
                    1672174799,
                    "DOCS"
                ]
        )

        await kali.propose(9, "TEST", [crowdsale.address], [1], [payload])
        await kali.vote(1, true)
        await advanceTime(35)
        await kali.processProposal(1)
        await crowdsale.callExtension(kali.address, getBigNumber(50))
        await crowdsale.callExtension(kali.address, getBigNumber(50))
        expect(await crowdsale.callExtension(kali.address, getBigNumber(50)).should.be.reverted)
        expect(await purchaseToken.balanceOf(proposer.address)).to.equal(
            getBigNumber(900)
        )
        expect(await purchaseToken.balanceOf(kali.address)).to.equal(
            getBigNumber(100)
        )
        expect(await kali.balanceOf(proposer.address)).to.equal(getBigNumber(210))
    })

    it("Should enforce purchase time limit", async function () {
        // Instantiate KaliDAO
        await kali.init(
          "KALI",
          "KALI",
          "DOCS",
          false,
          [],
          [],
          [proposer.address],
          [getBigNumber(10)],
          [30, 0, 0, 60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        )

        // Set up payload for extension proposal
        let payload = ethers.utils.defaultAbiCoder.encode(
            ["uint256", "address", "uint8", "uint96", "uint32", "string"],
                [
                    0,
                    "0x0000000000000000000000000000000000000000",
                    2,
                    getBigNumber(200),
                    1672174799,
                    "DOCS"
                ]
        )

        await kali.propose(9, "TEST", [crowdsale.address], [1], [payload])
        await kali.vote(1, true)
        await advanceTime(35)
        await kali.processProposal(1)
        await advanceTime(1672174799)
        expect(await crowdsale 
            .callExtension(kali.address, getBigNumber(50), {
                value: getBigNumber(50),
        }).should.be.reverted)
        expect(await ethers.provider.getBalance(kali.address)).to.equal(
            getBigNumber(0)
        )
    })
})
