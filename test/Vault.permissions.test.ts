import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";

import { Vault, VaultFactory, ManagerRegistry } from "../typechain-types";

/**
 * @title Mercuri Vault — Permissions & Trust Model
 *
 * @notice
 * This test suite validates the access-control, delegation, and trust assumptions
 * of the Mercuri Vault contract.
 *
 * @dev
 * These tests intentionally focus on *authorization boundaries*, not Uniswap behavior.
 * Uniswap interactions are assumed to be correct per upstream guarantees.
 *
 * IMPORTANT ASSUMPTIONS
 * ---------------------
 * - Tests are executed against a forked chain (Hardhat or Anvil)
 * - External Uniswap contracts exist at the specified addresses
 * - No liquidity position is created; tests focus on permission gating
 *
 * Run with:
 *   npx hardhat test --network hardhat
 */
describe("Mercuri Vault — Permissions & Trust Model", function () {
    let vault: Vault;
    let factory: VaultFactory;
    let registry: ManagerRegistry;

    let owner: Signer;
    let manager: Signer;
    let attacker: Signer;

    /** Uniswap V3 Factory */
    const UNISWAP_V3_FACTORY = "0x33128a8fC17869897dcE68Ed026d694621f6FDfD";

    /** Uniswap V3 Nonfungible Position Manager */
    const POSITION_MANAGER = "0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1";

    /** Uniswap SwapRouter02 */
    const SWAP_ROUTER = "0x2626664c2603336E57B271c5C0b26F421741e481";

    /** Canonical WETH on Base */
    const WETH = "0x4200000000000000000000000000000000000006";

    /** Example WETH/USDC 0.05% pool */
    const POOL = "0xd0b53d9277642d899df5c87a3966a349a798f224";

    /**
     * @notice Deploys a fresh protocol stack before each test.
     *
     * @dev
     * - ManagerRegistry is advisory only
     * - VaultFactory holds protocol-level configuration
     * - Vault is deployed with immutable owner + initial manager
     */
    beforeEach(async function () {
        [owner, manager, attacker] = await ethers.getSigners();

        const Registry = await ethers.getContractFactory("ManagerRegistry");
        registry = (await Registry.deploy()) as unknown as ManagerRegistry;

        // Manager is protocol-approved (advisory only)
        await registry.connect(owner).setApproved(await manager.getAddress(), true);

        const Factory = await ethers.getContractFactory("VaultFactory");
        factory = (await Factory.deploy(
            UNISWAP_V3_FACTORY,
            POSITION_MANAGER,
            registry.target,
            WETH,
            SWAP_ROUTER,
        )) as unknown as VaultFactory;

        // -------------------------
        // Deploy Vault
        // -------------------------
        const VaultContract = await ethers.getContractFactory("Vault");
        vault = (await VaultContract.deploy(
            factory.target,
            await owner.getAddress(),
            await manager.getAddress(),
            registry.target,
            POSITION_MANAGER,
            POOL,
            WETH,
            SWAP_ROUTER,
        )) as unknown as Vault;
    });

    /**
     * @notice Owner may update the operational manager.
     *
     * @security
     * This action is irreversible trust delegation and must remain owner-only.
     */
    it("allows owner to update manager", async function () {
        const newManager = await attacker.getAddress();

        await expect(vault.connect(owner).setManager(newManager))
            .to.emit(vault, "ManagerChanged")
            .withArgs(newManager);

        expect(await vault.manager()).to.equal(newManager);
    });

    /**
     * @notice Non-owners must never be able to change the manager.
     */
    it("prevents non-owner from updating manager", async function () {
        await expect(vault.connect(attacker).setManager(await attacker.getAddress())).to.be
            .reverted;
    });

    /**
     * @notice Authorized managers may perform operational actions.
     *
     * @dev
     * No Uniswap position exists; this test only asserts access control.
     */
    it("allows manager to perform operational actions", async function () {
        await expect(
            vault.connect(manager).collect({
                tokenId: 0,
                recipient: vault.target,
                amount0Max: 0,
                amount1Max: 0,
            }),
        ).to.not.be.revertedWith("not authorized");
    });

    /**
     * @notice Unauthorized addresses must not perform operational actions.
     */
    it("prevents attacker from performing operational actions", async function () {
        await expect(
            vault.connect(attacker).collect({
                tokenId: 0,
                recipient: vault.target,
                amount0Max: 0,
                amount1Max: 0,
            }),
        ).to.be.reverted;
    });

    /**
     * @notice Managers must never be able to withdraw funds.
     *
     * @security
     * Prevents delegated operators from stealing user capital.
     */
    it("prevents manager from withdrawing funds", async function () {
        await expect(vault.connect(manager).withdrawAll()).to.be.reverted;
    });

    /**
     * @notice External attackers must never be able to withdraw funds.
     */
    it("prevents attacker from withdrawing funds", async function () {
        await expect(vault.connect(attacker).withdrawAll()).to.be.reverted;
    });

    /**
     * @notice Owner may always withdraw funds.
     *
     * @dev
     * No balance exists in this test; success is defined as non-reversion.
     */
    it("allows owner to withdraw funds", async function () {
        await vault.connect(owner).withdrawAll();
    });

    /**
     * @notice Explicitly documents owner self-risk when assigning managers.
     *
     * @security
     * - Owner may assign a malicious manager
     * - Manager gains operational authority
     * - Manager STILL cannot withdraw funds
     *
     * This is an intentional design tradeoff.
     */
    it("documents owner self-risk when assigning malicious manager", async function () {
        await vault.connect(owner).setManager(await attacker.getAddress());

        // Attacker is now the manager
        expect(await vault.manager()).to.equal(await attacker.getAddress());

        // Capital remains protected
        await expect(vault.connect(attacker).withdrawAll()).to.be.reverted;
    });
});
