// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract MerkleMinter is ERC721, Ownable, Pausable, ReentrancyGuard {
    enum Phase { Inactive, Allowlist, Public }

    // ---------- Errors ----------
    error InvalidPhase();
    error InvalidProof();
    error ExceedsAllowance();
    error ExceedsPublicLimit();
    error SupplyExceeded();
    error IncorrectPayment();
    error WithdrawFailed();
    error ZeroAddress();

    // ---------- Events ----------
    event MerkleRootUpdated(bytes32 newRoot);
    event PriceUpdated(uint256 newPrice);
    event PhaseChanged(Phase newPhase);
    event Minted(address indexed to, uint256 indexed tokenId, Phase phase);
    event Withdrawn(address indexed to, uint256 amount);

    // ---------- State ----------
    bytes32 public merkleRoot;
    uint256 public price;
    uint256 public immutable maxSupply;
    Phase public phase;
    uint256 public publicMaxPerWallet;
    uint256 public totalMinted;
    string private _baseTokenURI;

    mapping(address => uint256) public allowlistMinted;
    mapping(address => uint256) public publicMinted;

    // ---------- Constructor ----------
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 price_,
        uint256 maxSupply_,
        uint256 publicMaxPerWallet_,
        bytes32 merkleRoot_,
        string memory baseURI_
    ) ERC721(name_, symbol_) Ownable(msg.sender) {
        price = price_;
        maxSupply = maxSupply_;
        publicMaxPerWallet = publicMaxPerWallet_;
        merkleRoot = merkleRoot_;
        _baseTokenURI = baseURI_;
        phase = Phase.Inactive;
    }

    // ---------- Admin controls ----------
    function setMerkleRoot(bytes32 newRoot) external onlyOwner {
        merkleRoot = newRoot;
        emit MerkleRootUpdated(newRoot);
    }

    function setPrice(uint256 newPrice) external onlyOwner {
        price = newPrice;
        emit PriceUpdated(newPrice);
    }

    function setPhase(Phase newPhase) external onlyOwner {
        phase = newPhase;
        emit PhaseChanged(newPhase);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // ---------- Allowlist mint ----------
    function mintAllowlist(uint256 allowance, bytes32[] calldata proof, uint256 quantity)
        external
        payable
        nonReentrant
        whenNotPaused
    {
        if (phase != Phase.Allowlist) revert InvalidPhase();

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, allowance))));
        if (!MerkleProof.verify(proof, merkleRoot, leaf)) revert InvalidProof();

        if (allowlistMinted[msg.sender] + quantity > allowance) revert ExceedsAllowance();
        if (totalMinted + quantity > maxSupply) revert SupplyExceeded();
        if (msg.value != price * quantity) revert IncorrectPayment();

        allowlistMinted[msg.sender] += quantity;
        _mintBatch(msg.sender, quantity, Phase.Allowlist);
    }

    // ---------- Public mint ----------
    function mintPublic(uint256 quantity) external payable nonReentrant whenNotPaused {
        if (phase != Phase.Public) revert InvalidPhase();

        if (publicMinted[msg.sender] + quantity > publicMaxPerWallet) revert ExceedsPublicLimit();
        if (totalMinted + quantity > maxSupply) revert SupplyExceeded();
        if (msg.value != price * quantity) revert IncorrectPayment();

        publicMinted[msg.sender] += quantity;
        _mintBatch(msg.sender, quantity, Phase.Public);
    }

    // ---------- Shared minting logic ----------
    function _mintBatch(address to, uint256 quantity, Phase mintPhase) internal {
        for (uint256 i = 0; i < quantity; i++) {
            totalMinted++;
            uint256 tokenId = totalMinted;
            _safeMint(to, tokenId);
            emit Minted(to, tokenId, mintPhase);
        }
    }

    // ---------- Withdrawal ----------
    function withdraw(address to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 balance = address(this).balance;
        (bool success, ) = to.call{value: balance}("");
        if (!success) revert WithdrawFailed();
        emit Withdrawn(to, balance);
    }

    // ---------- Metadata ----------
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }
}