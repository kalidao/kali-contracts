const { BigNumber } = require("ethers")
const chai = require("chai")
const { expect } = require("chai")

chai.should()

// Defaults to e18 using amount * 10^18
function getBigNumber(amount, decimals = 18) {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(decimals))
}

describe("Deployer", function () {
    let Kali // KaliDAO contract
    let kali // KaliDAO contract instance
    let alice // signerA
    let bob // signerB
    let carol // signerC
  
    beforeEach(async () => {
      ;[alice, bob, carol] = await ethers.getSigners()
  
      Kali = await ethers.getContractFactory("KaliDAO")
      kali = await Kali.deploy()
      await kali.deployed()
    })
  
    it("Should deploy Kali DAO", async function () {
        // Instantiate KaliDAO
        await kali.init(
          "KALI",
          "KALI",
          "DOCS",
          false,
          [],
          [],
          [alice.address],
          [getBigNumber(10)],
          [30, 0, 0, 60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        )

        expect(await kali.balanceOf(alice.address)).to.equal(getBigNumber(10))
    })
  })
