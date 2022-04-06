// SPDX-License-Identifier: MIT
// Creator: Chiru Labs
// Feb 23rd 2022, Modification for GAMA by John Whitton

pragma solidity ^0.8.4;

import '../ERC721G.sol';
import '@openzeppelin/contracts/utils/Context.sol';

/**
 * @title ERC721G Burnable Token
 * @dev ERC721G Token that can be irreversibly burned (destroyed).
 */
abstract contract ERC721GBurnable is Context, ERC721G {

    /**
     * @dev Burns `tokenId`. See {ERC721G-_burn}.
     *
     * Requirements:
     *
     * - The caller must own `tokenId` or be an approved operator.
     */
    function burn(uint256 tokenId) public virtual {
        TokenOwnership memory prevOwnership = ownershipOf(tokenId);

        bool isApprovedOrOwner = (_msgSender() == prevOwnership.addr ||
            isApprovedForAll(prevOwnership.addr, _msgSender()) ||
            getApproved(tokenId) == _msgSender());

        if (!isApprovedOrOwner) revert TransferCallerNotOwnerNorApproved();

        _burn(tokenId);
    }
}