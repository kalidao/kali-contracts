const { BigNumber } = require("ethers")
const chai = require("chai")
const { expect } = require("chai")
const { ethers } = require("hardhat");

chai.should()

// Defaults to e18 using amount * 10^18
function getBigNumber(amount, decimals = 18) {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(decimals))
}

async function advanceTime(time) {
  await ethers.provider.send("evm_increaseTime", [time])
}

describe("Redemption", function () {
    let Kali // KaliDAO contract
    let kali // KaliDAO contract instance
    let Token0 // Token0 contract
    let token0 // Token0 contract instance
    let Token1 // Token1 contract
    let token1 // Token1 contract instance
    let LootMaster // LootMaster contract
    let lootMaster // LootMaster contract instance
    let Redemption // Redemption contract
    let redemption // Redemption contract instance
    let proposer // signerA
    let alice // signerB
    let bob // signerC
  
    beforeEach(async () => {
      ;[proposer, alice, bob] = await ethers.getSigners()
  
      Kali = await ethers.getContractFactory("KaliDAO")
      kali = await Kali.deploy()
      await kali.deployed()

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

      Token0 = await ethers.getContractFactory("FixedERC20")
      token0 = await Token0.deploy(
        "DAI",
        "DAI",
        "18",
        kali.address,
        getBigNumber(1000)
      )
      await token0.deployed()

      Token1 = await ethers.getContractFactory("FixedERC20")
      token1 = await Token1.deploy(
        "LOOT",
        "LOOT",
        "18",
        proposer.address,
        getBigNumber(1000)
      )
      await token1.deployed()

      LootMaster = await ethers.getContractFactory("KaliSubDAOtoken")
      lootMaster = await LootMaster.deploy()
      await lootMaster.deployed()

      Redemption = await ethers.getContractFactory("KaliDAOredemption")
      redemption = await Redemption.deploy(lootMaster.address)
      await redemption.deployed()
      
      // Set up payload for token approval
      let payload = token0.interface.encodeFunctionData("approve", [
        redemption.address,
        getBigNumber(1000)
      ])

      await kali.propose(2, "TEST", [token0.address], [0], [payload])
      await kali.vote(1, true)
      await advanceTime(35)
      await kali.processProposal(1)

      // Set up payload for loot deployment
      //let payload2 = ethers.utils.defaultAbiCoder.encode(
      //  ["string", "string", "bool", "address[]", "uint256[]"],
      //  [
      //  "LOOT",
      //  "LOOT",
      //  true,
      //  [proposer.address],
      //  [getBigNumber(1000)],
      //  ]
      //)

      //await kali.propose(2, "TEST", [redemption.address], [0], [payload2])
      //await kali.vote(2, true)
      //await advanceTime(35)
      //await kali.processProposal(2)

      //let loot = await redemption.redemptions(kali.address).lootToken

      // Set up payload for extension proposal
      let payload3 = ethers.utils.defaultAbiCoder.encode(
        ["address", "uint32", "bool"],
        [
        token1.address, // this is merely placeholder for 'loot'
        0,
        true,
        ]
      )

      await kali.propose(9, "TEST", [redemption.address], [0], [payload3])
      await kali.vote(2, true)
      await advanceTime(35)
      await kali.processProposal(2)
    })
  
    it("Should allow redemption of shares", async function () {
      expect(await token0.balanceOf(proposer.address)).to.equal(
        getBigNumber(0)
      )
      expect(await token0.balanceOf(kali.address)).to.equal(
        getBigNumber(1000)
      )

      kali.approve(redemption.address, getBigNumber(10))

      redemption.callExtension(kali.address, [token0.address], 0, getBigNumber(10))

      expect(await token0.balanceOf(proposer.address)).to.equal(
        getBigNumber(1000)
      )
      expect(await token0.balanceOf(kali.address)).to.equal(
        getBigNumber(0)
      )
    })
  }) 
