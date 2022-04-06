// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import "./ERC721G/ERC721G.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./@rarible/royalties/contracts/impl/RoyaltiesV2Impl.sol";
import "./@rarible/royalties/contracts/LibPart.sol";
import "./@rarible/royalties/contracts/LibRoyaltiesV2.sol";


/// By John Whitton (@johnwhitton), Aaron Li (@polymorpher)
contract GAMAv2 is ERC721G, Ownable, RoyaltiesV2Impl {
    bytes32 internal salt;
    uint256 public maxGamaTokens;
    uint256 public mintPrice;
    uint256 public maxPerMint;
    uint256 public startIndex;

    string public provenanceHash = "";
    uint256 public offsetValue;

    bool public metadataFrozen;
    bool public provenanceFrozen;
    bool public saleIsActive;
    bool public saleStarted;

    mapping(uint256 => string) internal metadataUris;
    string internal _contractUri;
    string public temporaryTokenUri;
    string internal baseUri;
    address internal revenueAccount;

    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    event SetBaseUri(string baseUri);
    event SetStartIndex(uint256 index);
    event GAMAMint(uint256 lastTokenId, uint256 numTokens, address initialOwner);
    event GAMAMintCommunity(uint256 lastTokenId, uint256 numTokens, address initialOwner);
    event GAMABurn(uint256 id);
    event GAMABatchBurn(uint256[] ids);
    event GAMATransfer(uint256 id, address from, address to, address operator);
    event GAMASetup(uint32 coolingPeriod_, uint32 shipNumber_, string contractUri);

    constructor(bool _saleIsActive, bool _metadataFrozen, bool _provenanceFrozen, uint256 _maxGamaTokens, uint256 _mintPrice, uint256 _maxPerMint, string memory _baseUri, string memory contractUri_) ERC721G("GAMA Space Station v2", "GAMAv2") {
        saleIsActive = _saleIsActive;
        if (saleIsActive) {
            saleStarted = true;
        }
        metadataFrozen = _metadataFrozen;
        provenanceFrozen = _provenanceFrozen;
        maxGamaTokens = _maxGamaTokens;
        mintPrice = _mintPrice;
        maxPerMint = _maxPerMint;

        baseUri = _baseUri;
        _contractUri = contractUri_;
    }

    modifier whenSaleActive {
        require(saleIsActive, "GAMAv2: Sale is not active");
        _;
    }

    modifier whenMetadataNotFrozen {
        require(!metadataFrozen, "GAMAv2: Metadata is frozen");
        _;
    }

    modifier whenProvenanceNotFrozen {
        require(!provenanceFrozen, "GAMAv2: Provenance is frozen");
        _;
    }

    // ------------------
    // Explicit overrides
    // ------------------

    function _burn(uint256 tokenId) internal virtual override(ERC721G) {
        super._burn(tokenId);
    }

    function setTemporaryTokenUri(string memory uri) public onlyOwner {
        temporaryTokenUri = uri;
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721G) returns (string memory) {
        if (!metadataFrozen && bytes(temporaryTokenUri).length > 0) {
            return temporaryTokenUri;
        }
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();
        uint256 tid = tokenId;
        if (tid >= offsetValue) {
            tid = (startIndex + tid) % (maxGamaTokens - offsetValue) + offsetValue;
        }

        if (bytes(metadataUris[tokenId]).length == 0) {
            return bytes(baseUri).length != 0 ? string(abi.encodePacked(baseUri, uint2str(tid))) : '';
        }
        return metadataUris[tokenId];
    }

    function setStartIndex() external onlyOwner {
        startIndex = uint256(keccak256(abi.encodePacked(blockhash(block.number - 2), bytes20(msg.sender), bytes32(totalSupply())))) % (maxGamaTokens - offsetValue);
        emit SetStartIndex(startIndex);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseUri;
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == this.name.selector ||
        interfaceId == this.symbol.selector ||
        interfaceId == LibRoyaltiesV2._INTERFACE_ID_ROYALTIES ||
        interfaceId == _INTERFACE_ID_ERC2981 ||
        ERC721G.supportsInterface(interfaceId);
    }

    // ------------------
    // Utility view functions
    // ------------------

    function exists(uint256 _tokenId) public view returns (bool) {
        return _exists(_tokenId);
    }

    //TODO review if we need to override the contractURI
    function contractURI() public view returns (string memory) {
        return _contractUri;
    }


    // ------------------
    // Functions for external (user) minting
    // ------------------

    function mintGAMA(uint256 amount) external payable whenSaleActive {
        require(totalSupply() + amount < maxGamaTokens, "GAMAv2: Purchase would exceed cap");
        require(amount <= maxPerMint, "GAMAv2: Amount exceeds max per mint");
        require(mintPrice * amount <= msg.value, "GAMAv2: Ether value sent is not correct");
        uint256 excess = msg.value - (amount * mintPrice);
        if (excess > 0) {
            payable(msg.sender).transfer(excess);
        }
        _safeMint(msg.sender, amount);
        emit GAMAMint(totalSupply(), amount, msg.sender);
    }

    function burn(uint256 id) public onlyOwner() whenMetadataNotFrozen() {
        ERC721G._burn(id);
        emit GAMABurn(id);
    }

    function batchBurn(uint256[] memory ids) public onlyOwner() whenMetadataNotFrozen() {
        for (uint32 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            ERC721G._burn(id);
        }
        emit GAMABatchBurn(ids);
    }

    // ------------------
    // Functions for the owner (GAMA minting contracts)
    // ------------------

    function freezeMetadata() external onlyOwner whenMetadataNotFrozen {
        metadataFrozen = true;
    }

    function freezeProvenance() external onlyOwner whenProvenanceNotFrozen {
        provenanceFrozen = true;
    }

    function toggleSaleState() external onlyOwner {
        saleIsActive = !saleIsActive;
        if (saleIsActive && !saleStarted) {
            // This is a bug, but it doesn't matter  
            saleStarted; 
        }
    }

    function setContractUri(string memory uri_) public onlyOwner() {
        _contractUri = uri_;
    }

    function setProvenanceHash(string memory _provenanceHash) external onlyOwner whenProvenanceNotFrozen {
        provenanceHash = _provenanceHash;
    }

    function setOffsetValue(uint256 _offsetValue) external onlyOwner {
        require(!saleStarted, "sale already begun");
        offsetValue = _offsetValue;
    }

    function setMaxPerMint(uint256 _maxPerMint) external onlyOwner {
        maxPerMint = _maxPerMint;
    }

    function setMintPrice(uint256 _mintPrice) external onlyOwner {
        mintPrice = _mintPrice;
    }

    function setBaseUri(string memory _baseUri) external onlyOwner whenMetadataNotFrozen {
        baseUri = _baseUri;
        emit SetBaseUri(baseUri);
    }

    function mintForCommunity(address _to, uint256 _numberOfTokens) external onlyOwner {
        require(_to != address(0), "GAMAv2: Cannot mint to zero address.");
        require(totalSupply() + _numberOfTokens < maxGamaTokens, "GAMAv2: Minting would exceed cap");
        _safeMint(_to, _numberOfTokens);
        emit GAMAMintCommunity(totalSupply(), _numberOfTokens, _to);
    }

    function withdraw(uint256 amount, bool shouldUseRevenueAccount) public {
        require(msg.sender == Ownable.owner() || msg.sender == revenueAccount, "unauthorized");
        address a = shouldUseRevenueAccount ? revenueAccount : Ownable.owner();
        (bool success,) = a.call{value : amount}("");
        require(success);
    }

    function setUri(uint256 id, string memory uri_) public onlyOwner() whenMetadataNotFrozen {
        metadataUris[id] = uri_;
    }

    function uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    function setRevenueAccount(address account) public onlyOwner() {
        revenueAccount = account;
    }

    function setRoyalties(uint _tokenId, address payable _royaltiesReceipientAddress, uint96 _percentageBasisPoints) public  onlyOwner() {
        LibPart.Part[] memory _royalties = new LibPart.Part[](1);
        _royalties[0].value = _percentageBasisPoints;
        _royalties[0].account = _royaltiesReceipientAddress;
        _saveRoyalties(_tokenId, _royalties);
    }

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external  view returns (address receiver, uint256 royaltyAmount) {
        LibPart.Part[] memory _royalties = royalties[_tokenId];
        if (_royalties.length > 0) {
            return (_royalties[0].account, (_salePrice * _royalties[0].value) / 10000);
        }
        return (address(0), 0);

    }

    receive() external payable {

    }

    // ------------------
    // Utility function for getting the tokens of a certain address
    // ------------------

    function tokensOfOwner(address _owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);
        if (tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            for (uint256 index; index < tokenCount; index++) {
                result[index] = tokenOfOwnerByIndex(_owner, index);
            }
            return result;
        }
    }
}