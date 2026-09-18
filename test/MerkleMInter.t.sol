// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MerkleMinter} from "../src/MerkleMinter.sol";

contract MerkleMinterTest is Test {
    MerkleMinter minter;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address carol = makeAddr("carol");
    address dave = makeAddr("dave");
    address stranger = makeAddr("stranger");

    uint256 constant ALICE_ALLOWANCE = 3;
    uint256 constant BOB_ALLOWANCE = 2;
    uint256 constant CAROL_ALLOWANCE = 1;
    uint256 constant DAVE_ALLOWANCE = 5;

    uint256 constant PRICE = 0.01 ether;
    uint256 constant MAX_SUPPLY = 100;
    uint256 constant PUBLIC_MAX_PER_WALLET = 5;

    bytes32 merkleRoot;
    bytes32 leafAlice;
    bytes32 leafBob;
    bytes32 leafCarol;
    bytes32 leafDave;
    bytes32 nodeAB;
    bytes32 nodeCD;

    function setUp() public {
        leafAlice = keccak256(bytes.concat(keccak256(abi.encode(alice, ALICE_ALLOWANCE))));
        leafBob   = keccak256(bytes.concat(keccak256(abi.encode(bob, BOB_ALLOWANCE))));
        leafCarol = keccak256(bytes.concat(keccak256(abi.encode(carol, CAROL_ALLOWANCE))));
        leafDave  = keccak256(bytes.concat(keccak256(abi.encode(dave, DAVE_ALLOWANCE))));

        nodeAB = _hashPair(leafAlice, leafBob);
        nodeCD = _hashPair(leafCarol, leafDave);
        merkleRoot = _hashPair(nodeAB, nodeCD);

        minter = new MerkleMinter(
            "TestNFT",
            "TNFT",
            PRICE,
            MAX_SUPPLY,
            PUBLIC_MAX_PER_WALLET,
            merkleRoot,
            "ipfs://base/"
        );

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(carol, 10 ether);
        vm.deal(dave, 10 ether);
        vm.deal(stranger, 10 ether);
    }

    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    function _aliceProof() internal view returns (bytes32[] memory proof) {
        proof = new bytes32[](2);
        proof[0] = leafBob;
        proof[1] = nodeCD;
    }

    function _bobProof() internal view returns (bytes32[] memory proof) {
        proof = new bytes32[](2);
        proof[0] = leafAlice;
        proof[1] = nodeCD;
    }

    function _carolProof() internal view returns (bytes32[] memory proof) {
        proof = new bytes32[](2);
        proof[0] = leafDave;
        proof[1] = nodeAB;
    }

    // ---------- Main flow ----------
    function test_MintAllowlist_ValidProof() public {
        vm.prank(address(this));
        minter.setPhase(MerkleMinter.Phase.Allowlist);

        vm.prank(alice);
        minter.mintAllowlist{value: PRICE}(ALICE_ALLOWANCE, _aliceProof(), 1);

        assertEq(minter.ownerOf(1), alice);
        assertEq(minter.allowlistMinted(alice), 1);
    }

    // ---------- Invalid proof ----------
    function test_RevertWhen_InvalidProof() public {
        vm.prank(address(this));
        minter.setPhase(MerkleMinter.Phase.Allowlist);

        vm.prank(stranger);
        vm.expectRevert(MerkleMinter.InvalidProof.selector);
        minter.mintAllowlist{value: PRICE}(1, _aliceProof(), 1);
    }

    // ---------- Inactive phase ----------
    function test_RevertWhen_MintingDuringInactivePhase() public {
        vm.prank(alice);
        vm.expectRevert(MerkleMinter.InvalidPhase.selector);
        minter.mintAllowlist{value: PRICE}(ALICE_ALLOWANCE, _aliceProof(), 1);
    }

    // ---------- Duplicate claim / exceeds allowance ----------
    function test_RevertWhen_ExceedsAllowance() public {
        vm.prank(address(this));
        minter.setPhase(MerkleMinter.Phase.Allowlist);

        vm.startPrank(carol);
        minter.mintAllowlist{value: PRICE}(CAROL_ALLOWANCE, _carolProof(), 1);

        vm.expectRevert(MerkleMinter.ExceedsAllowance.selector);
        minter.mintAllowlist{value: PRICE}(CAROL_ALLOWANCE, _carolProof(), 1);
        vm.stopPrank();
    }

    // ---------- Supply exhaustion ----------
    function test_RevertWhen_SupplyExceeded() public {
        MerkleMinter tinyMinter = new MerkleMinter(
            "TinyNFT",
            "TINY",
            PRICE,
            2,              // maxSupply — deliberately tiny
            5,              // publicMaxPerWallet — larger than maxSupply, so it's never the blocker
            merkleRoot,
            "ipfs://base/"
        );

        vm.prank(address(this));
        tinyMinter.setPhase(MerkleMinter.Phase.Public);

        vm.prank(dave);
        tinyMinter.mintPublic{value: PRICE * 2}(2); // mints both available tokens, supply now full

        vm.prank(dave);
        vm.expectRevert(MerkleMinter.SupplyExceeded.selector);
        tinyMinter.mintPublic{value: PRICE}(1); // 1 more — exceeds remaining supply
    }

    // ---------- Payment checks ----------
    function test_RevertWhen_IncorrectPayment() public {
        vm.prank(address(this));
        minter.setPhase(MerkleMinter.Phase.Allowlist);

        vm.prank(alice);
        vm.expectRevert(MerkleMinter.IncorrectPayment.selector);
        minter.mintAllowlist{value: PRICE - 1}(ALICE_ALLOWANCE, _aliceProof(), 1);
    }

    function testFuzz_RevertWhen_WrongPayment(uint256 wrongValue) public {
        vm.assume(wrongValue != PRICE && wrongValue < 100 ether);

        vm.prank(address(this));
        minter.setPhase(MerkleMinter.Phase.Allowlist);

        vm.deal(alice, 100 ether);
        vm.prank(alice);
        vm.expectRevert(MerkleMinter.IncorrectPayment.selector);
        minter.mintAllowlist{value: wrongValue}(ALICE_ALLOWANCE, _aliceProof(), 1);
    }

    // ---------- Public mint ----------
    function test_MintPublic_ValidFlow() public {
        vm.prank(address(this));
        minter.setPhase(MerkleMinter.Phase.Public);

        vm.prank(stranger);
        minter.mintPublic{value: PRICE}(1);

        assertEq(minter.ownerOf(1), stranger);
    }

    function test_RevertWhen_ExceedsPublicLimit() public {
        vm.prank(address(this));
        minter.setPhase(MerkleMinter.Phase.Public);

        vm.startPrank(stranger);
        vm.expectRevert(MerkleMinter.ExceedsPublicLimit.selector);
        minter.mintPublic{value: PRICE * (PUBLIC_MAX_PER_WALLET + 1)}(PUBLIC_MAX_PER_WALLET + 1);
        vm.stopPrank();
    }

    // ---------- Phase transitions ----------
    function test_PhaseTransitions() public {
        assertEq(uint256(minter.phase()), uint256(MerkleMinter.Phase.Inactive));

        vm.prank(address(this));
        minter.setPhase(MerkleMinter.Phase.Allowlist);
        assertEq(uint256(minter.phase()), uint256(MerkleMinter.Phase.Allowlist));

        vm.prank(address(this));
        minter.setPhase(MerkleMinter.Phase.Public);
        assertEq(uint256(minter.phase()), uint256(MerkleMinter.Phase.Public));
    }
}