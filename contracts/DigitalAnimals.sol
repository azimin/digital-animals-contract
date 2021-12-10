// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./ReentrancyGuard.sol";
import "./Creators.sol";
import "./Signable.sol";

contract DigitalAnimals is ERC721Enumerable, VRFConsumerBase, Ownable, Signable, ReentrancyGuard, Creators {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    
    enum Phase { NONE, PRE_SALE, MAIN_SALE }
    
    // Constants
    uint256 public constant maxSupply = 8888;
    uint256 public constant mintPrice = 0.1 ether;
    uint256 public constant mainSaleMintPerAccount = 2;

    // Phase
    Phase private _phase;
    
    // Base URI
    string private _baseTokenURI;
    string private _baseContractURI;
    
    // Minting by account on different phases
    mapping(address => uint256) public mintedPreSale;
    mapping(address => uint256) public mintedMainSale;

    // Original minter
    mapping(uint256 => address) public originalMinter;
    
    // Counter
    Counters.Counter private _tokenCount;

    // Flag
    bool private gotGiftMints = false;

    // Random
    bool public randomRevealed = false;
    uint256 public randomValue = 0;

    // TODO: Rinkeby now
    address private VRFCoodinator = 0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B;
    address private LINKToken = 0x01BE23585060835E02B77ef475b0Cc51aA1e0709;
    bytes32 internal keyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
    uint256 internal fee = 0.1 ether;
    
    modifier onlyCreators {
        require(msg.sender == owner() || isCreator(msg.sender));
        _;
    }
    
    modifier phaseRequired(Phase phase_) {
        require(phase_ == phase(), "Mint not available on current phase");
        _;
    }
    
    modifier costs(uint price) {
        if (isCreator(msg.sender) == false) {
            require(msg.value >= price, "msg.value should be more or eual than price");   
        }
        _;
    }
    
    constructor() 
        ERC721("Digitals Aniamls", "DALS")
        VRFConsumerBase(VRFCoodinator, LINKToken)
    {
        string memory baseTokenURI = "https://digitalanimals.club/animal/"; // TODO: Fix links
        string memory baseContractURI = "https://digitalanimals.club/files/metadata.json"; // TODO: Fix links

        _baseTokenURI = baseTokenURI;
        _baseContractURI = baseContractURI;
    }

    receive() external payable { }

    fallback() external payable { }
    
    function setBaseURI(string memory baseURI_) public onlyOwner {
        _baseTokenURI = baseURI_;
    }
    
    function setContractURI(string memory baseContractURI_) public onlyOwner {
        _baseContractURI = baseContractURI_;
    }

    function mintForGifts() public onlyOwner lock { 
        require(gotGiftMints == false, "Already minted");
        uint256 amount = 22;

        uint256 total = totalToken();
        require(total + amount <= maxSupply, "Max limit");

        for (uint i; i < amount; i++) {
            _tokenCount.increment();
            _safeMint(msg.sender, totalToken());
            originalMinter[totalToken()] = msg.sender;
        }

        gotGiftMints = true;
    }
    
    function mintMainSale(uint256 amount, bytes calldata signature) public payable costs(mintPrice * amount) phaseRequired(Phase.MAIN_SALE) {
        _mint(amount, mainSaleMintPerAccount, signature, Phase.MAIN_SALE);
    }
    
    function mintPreSale(uint256 amount, uint256 maxAmount, bytes calldata signature) public payable costs(mintPrice * amount) phaseRequired(Phase.PRE_SALE) {
        _mint(amount, maxAmount, signature, Phase.PRE_SALE);
    }
    
    function setPhase(Phase phase_) public onlyOwner {
        _phase = phase_;
    }

    function reveal() public onlyCreators lock returns (bytes32 requestId) {
        require(!randomRevealed, "Chainlink VRF already requested");
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        randomRevealed = true;
        return requestRandomness(keyHash, fee);
    }
    
    function withdrawAll() public onlyCreators {
        uint256 balance = address(this).balance;
        require(balance > 0);
        
        _widthdraw(creator1, balance.mul(3).div(100));
        _widthdraw(creator2, balance.mul(3).div(100));
        _widthdraw(creator3, balance.mul(3).div(100));
        _widthdraw(creator4, balance.mul(3).div(200));
        _widthdraw(creator5, balance.mul(6).div(100));
        _widthdraw(creator6, balance.mul(20).div(100));
        _widthdraw(creator7, balance.mul(20).div(100));
        _widthdraw(creator8, balance.mul(20).div(100));
        _widthdraw(creator9, balance.mul(20).div(100));
        _widthdraw(creator10, address(this).balance);
    }
    
    function phase() public view returns (Phase) {
        return _phase;
    }
    
    function contractURI() public view returns (string memory) {
        return _baseContractURI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721)
        returns (string memory)
    {
        require(tokenId > 0 && tokenId <= totalSupply(), "Token not exist.");
        return string(abi.encodePacked(_baseURI(), metadataOf(tokenId)));
    }
    
    function totalToken() public view returns (uint256) {
        return _tokenCount.current();
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        if (randomness == 0) {
            randomValue = 1;
        } else {
            randomValue = randomness;
        }
    }

    function _mint(uint256 amount, uint256 maxAmount, bytes calldata signature, Phase phase_) private lock {
        require(!Address.isContract(msg.sender), "Address is contract");

        uint256 total = totalToken();
        require(total + amount <= maxSupply, "Max limit");

        require(maxAmount <= 3, "You can't mint more than 3 tokens");
        require(_verify(signer(), _hash(msg.sender, maxAmount), signature), "Invalid signature");

        if (phase_ == Phase.PRE_SALE) {
            uint256 minted = mintedPreSale[msg.sender];
            require(minted + amount <= maxAmount, "Already minted maximum on pre-sale");
            mintedPreSale[msg.sender] = minted + amount;
        } else {
            uint256 minted = mintedMainSale[msg.sender];
            require(minted + amount <= maxAmount, "Already minted maximum on main-sale");
            mintedMainSale[msg.sender] = minted + amount;
        }
        
        for (uint i; i < amount; i++) {
            _tokenCount.increment();
            _safeMint(msg.sender, totalToken());
            originalMinter[totalToken()] = msg.sender;
        }
    }
    
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function depricatedMetadataOf(uint256 tokenId) private view returns (string memory) {
        if (randomValue == 0) {
            return "hidden";
        }

        uint256[] memory metadata = new uint256[](maxSupply);
        for (uint256 i = 0; i < maxSupply; i += 1) {
            metadata[i] = i;
        }

        for (uint256 i = 0; i < maxSupply; i += 1) {
            uint256 j = (uint256(keccak256(abi.encode(randomValue, i))) % (maxSupply));
            (metadata[i], metadata[j]) = (metadata[j], metadata[i]);
        }

        return Strings.toString(metadata[tokenId]);
    }

    function metadataOf(uint256 tokenId) private view returns (string memory) {
        if (randomValue == 0) {
            return "hidden";
        }

        uint256 shift = randomValue % maxSupply;
        uint256 newId = tokenId + shift;
        if (newId > maxSupply) {
            newId = newId - maxSupply;
        }

        return Strings.toString(newId);
    }

    function _widthdraw(address _address, uint256 _amount) private {
        (bool success, ) = _address.call{value: _amount}("");
        require(success, "Widthdraw failed");
    }
    
    function _verify(address signer, bytes32 hash, bytes memory signature) private pure returns (bool) {
        return signer == ECDSA.recover(hash, signature);
    }
    
    function _hash(address account, uint256 amount) private pure returns (bytes32) {
        return ECDSA.toEthSignedMessageHash(keccak256(abi.encodePacked(account, amount)));
    }
}