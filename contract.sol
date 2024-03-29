// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GlassToken is ERC721, ERC721Enumerable, ERC721URIStorage, ERC721Burnable, Pausable, Ownable {   
   
   event UserRegistered(string message, uint256 time);
    event UserVerified(string message, uint256 time);
    event PhaseCreated(string message, uint256 time);
    event PhaseActivated(string message, uint256 time);
    event PhaseDeactivated(string message, uint256 time);
    event MintedSuccessfully(string message, uint256 time);
    event LimitUpdated(string message, uint256 time);
    event Transfer(string message, uint256 time);
    event UpdatedURI(string message, uint256 time);

   struct User {
        address userAdd;
        uint256 limit;
        bool isRegistered;
        string userRole;
        bool isVerified;
    }

    struct phase {
        uint256 reservedLimit;
        bool isActive;
        bool isCreated;
        uint256 premiumLimit;
        uint256 normalLimit;
        mapping(address => uint256) premiumUserBalance;
        mapping(address => uint256) normalUserBalance;
    }

    struct bulkNFTs {
        uint256 id;
        string uri;
    }

    mapping(uint256 => phase) public phasesMapping;
    mapping(address => User) public  UserMapping;
    mapping(address => bool) public AdminMapping;

    uint256 public maxMintingLimit;
    uint256 public platformMintingLimit;
    uint256 public userMintingLimit;
    uint256 public premiumGlobalLimit;
    uint256 public normalGlobalLimit;
    uint256 public currentPhase;
    bool public isTransferrable;

    error IncorrectRole();
    error UserNotRegistered();
    error UserPhaseLimitExceeded();

    constructor(uint256 _maxLimit, uint256 _platformLimit) ERC721("GlassToken", "GTN") {
        maxMintingLimit = _maxLimit;
        platformMintingLimit = _platformLimit;
        userMintingLimit = maxMintingLimit - platformMintingLimit;
    }
/**
* @dev  Register function for premium and normal users which can only be called by the owner
* requirements:
* - premium & normal user should not be already registered.
* - user should not be already registered as admin.
* - account address should not be zero
* @param _userAdd - address of the user
* @param _userRole - type of user

* emits a (UserRegistered) event.
*/
    function registerUser(
        address _userAdd,
        string memory _userRole
    ) public onlyOwner whenNotPaused{
        require(
            UserMapping[_userAdd].isRegistered == false,
            "User Registered Already as Normal"
        );
        require(
            AdminMapping[_userAdd] == false,
            "User Registered Already as Admin"
        );
        require(
            _userAdd != address(0),
            "Invalid Address"
        );
        
       bytes32 userRoleHash = keccak256(abi.encodePacked(_userRole));
       if(userRoleHash == keccak256(abi.encodePacked("premium"))) {
           require(
            premiumGlobalLimit > 0,
            "User Global Limit not set"
        );
           UserMapping[_userAdd] = User(_userAdd, premiumGlobalLimit, true, _userRole, false);
       }
       else if(userRoleHash == keccak256(abi.encodePacked("normal"))) {
           require(
            normalGlobalLimit > 0,
            "User Global Limit not set"
        );
           UserMapping[_userAdd] = User(_userAdd, normalGlobalLimit, true, _userRole, true);
       }
       else if(userRoleHash == keccak256(abi.encodePacked("admin"))) {
           AdminMapping[_userAdd] = true;
       }
       else {
           revert IncorrectRole ();
       }
        emit UserRegistered("User Registred", block.timestamp);
    }

    function setGlobalLimit(uint256 premium, uint256 normal) public onlyOwner whenNotPaused {
        premiumGlobalLimit = premium;
        normalGlobalLimit = normal;
    }

    
/**
* @dev  this function can only be called by the owner to verify premium user 
* requirements:
* - user should be registered.
* - user should not be already verified.
* @param _userAdd - address of the user to verify

* emits a (UserVerified) event.
*/
    function verifyPremium(address _userAdd) public onlyOwner whenNotPaused {
        require(UserMapping[_userAdd].isRegistered == true, "User Not Registered");
        require(UserMapping[_userAdd].isVerified == false, "User Already Verified");
        UserMapping[_userAdd].isVerified = true;

        emit UserVerified("User Verified", block.timestamp);
    }
/**
* @dev  phase creation which can only be called by the owner
* requirements:
* - phase should not be created already
* - phase should not be activated already
* - phase limit should be less than user minting limit

* @param _reservedLimit - limit of the entire phase
* @param _premiumLimit - premium user limit per address
* @param _normalLimit - normal user limit per address

* emits a (PhaseCreated) event.
*/
    function createPhase(
        uint256 _reservedLimit,
        uint256 _premiumLimit,
        uint256 _normalLimit     
        ) public onlyOwner whenNotPaused {
            require(
                phasesMapping[currentPhase].isCreated == false,
                "Phase already created"
            );
            require(
                phasesMapping[currentPhase].isActive == false,
                "Phase already active"
            );
            require(
                _reservedLimit <= userMintingLimit,
                "limit exceeded"
            );
        
           phasesMapping[currentPhase].reservedLimit = _reservedLimit;
           phasesMapping[currentPhase].premiumLimit = _premiumLimit;
           phasesMapping[currentPhase].normalLimit = _normalLimit;  
           phasesMapping[currentPhase].isCreated = true;

           emit PhaseCreated("Phase Created", block.timestamp);
    }
/**
* @dev  phase activation which can only be called by the owner
* requirements:
* - phase should be created already
* - phase should not be already active
* - reserved limit should not be zero

* emits a (PhaseActivated) event.
*/    
    function activatePhase() public onlyOwner whenNotPaused {
        require(
            phasesMapping[currentPhase].isActive == false, 
            "Phase Already Active " 
        );
        require(
            phasesMapping[currentPhase].isCreated == true,
            "Phase Not Created"
        );
        require(
            phasesMapping[currentPhase].reservedLimit != 0,
            "Set Reserved Limit"
        );
        phasesMapping[currentPhase].isActive = true;
        emit PhaseActivated("Phase Activated", block.timestamp);
    }
/**
* @dev  phase deactivation which can only be called by the owner
* requirements:
* - phase should be created & active already
* - premium limit should not be zero

* emits a (PhaseDeactivated) event.
*/    
    function deactivatePhase() public onlyOwner whenNotPaused {
        require(
            phasesMapping[currentPhase].isActive == true,
            "Phase Not Active"
        );
        require(
            phasesMapping[currentPhase].isCreated == true,
            "Create Phase First"
        );
        require(
            phasesMapping[currentPhase].premiumLimit != 0, // used premium limit because it's static. We can also use normal limit.
            "Phase Not Created"
        );
        phasesMapping[currentPhase].isActive = false;
        currentPhase++;
        emit PhaseDeactivated("Phase Deactivated", block.timestamp);
    }
/*
* @dev  NFT mint function for premium & normal user
* requirements:
* - user should already be resigtered
* - premium user can mint only if he is verified
* - phase should be active
* - user minting limit & reserved limit should be greater than 0
* - tokenId should be in the range of total NFT minting limit
* - metadata hash should be 64 bytes
* - user cannot mint more than its global limit
* - user cannot mint more than the phase limit allowed per address

* @param to - address to whom NFT is to be sent
* @param tokenId - user has to add token Id
* @param uri - metadata hash of the NFT

* emits a (Transfer) event from library.
*/  
    function safeMint(uint256 tokenId, string memory uri) public {
        require(
            UserMapping[msg.sender].isVerified,
            "User Not Verified"
            );
        require(
            phasesMapping[currentPhase].isActive,
            "Phase Not Active"
        );
        require(
            userMintingLimit > 0,
            "User Limit Exceeded"
        );
        require(
            phasesMapping[currentPhase].reservedLimit > 0,
            "Phase Reserved Limit Exceeded"
        );
        require(
            tokenId > 0 && tokenId <= maxMintingLimit, 
            "Add token Id under Max Minting Limit"
        );
        require(
              UserMapping[msg.sender].limit > 0,
              "Balance is Greater Than Global Limit"
        );

        bytes32 userRoleHash = keccak256(abi.encodePacked(UserMapping[msg.sender].userRole));
        
         if (userRoleHash == keccak256(abi.encodePacked("premium"))) {
        require(
            phasesMapping[currentPhase].premiumLimit > phasesMapping[currentPhase].premiumUserBalance[msg.sender], 
            "Premium Phase Limit Exceeded"
        );
        phasesMapping[currentPhase].premiumUserBalance[msg.sender]++;
        }
        else if (userRoleHash == keccak256(abi.encodePacked("normal"))) {
        require(
            phasesMapping[currentPhase].normalLimit > phasesMapping[currentPhase].normalUserBalance[msg.sender],
            "Normal Phase Limit Exceeded"
            );
           phasesMapping[currentPhase].normalUserBalance[msg.sender]++;
        } 
        else {
            revert UserPhaseLimitExceeded();
        }   
        userMintingLimit--;
        phasesMapping[currentPhase].reservedLimit--;
        UserMapping[msg.sender].limit--;

        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, uri);
    }
    
/*
* @dev  premium & normal user can mint more than 1 NFT
* requirements:
* - all from safeMint
* - length of uri, token Id, and address should be equal

* @param to - address to whom NFT is to be sent
* @param tokenId - user has to add token Id
* @param uri - metadata hash of the NFT

* emits a (MintedSuccessfully) event.
*/ 
    function bulkMint( uint256[] memory tokenId, string[] memory uri) public whenNotPaused {
        require(
           tokenId.length == uri.length,
            "Valid Length Required"
        );
         require(
            UserMapping[msg.sender].isVerified,
            "User Not Registered or Verified"
        );
        require(
            phasesMapping[currentPhase].isActive,
            "Phase Not Active"
        );
        require(
            userMintingLimit - uri.length > 0,  // we can put any parameter here because of the 1st check
            "User Limit Exceeded"
        );
        require(
            phasesMapping[currentPhase].reservedLimit - uri.length > 0,
            "Phase Reserved Limit Exceeded"
        );
         require(
            UserMapping[msg.sender].limit - uri.length > 0,
            "Global Limit Exceeded"
        );

        for(uint256 i=0; i < tokenId.length; i++){
            require(
            tokenId[i] >0 && tokenId[i] <= maxMintingLimit,
            "Token Id out of Range"
            );
        }
        for(uint256 i=0; i < uri.length; i++){
            bytes32 userRoleHash = keccak256(abi.encodePacked(UserMapping[msg.sender].userRole));
            if (userRoleHash == keccak256(abi.encodePacked("premium"))) {
            require(
                phasesMapping[currentPhase].premiumUserBalance[msg.sender] + (uri.length - i) <= phasesMapping[currentPhase].premiumLimit,
                "Premium Phase Limit Exceeded"
                );
               phasesMapping[currentPhase].premiumUserBalance[msg.sender]++;
            } else if (userRoleHash == keccak256(abi.encodePacked("normal"))) {
                require(
                    phasesMapping[currentPhase].normalUserBalance[msg.sender] + (uri.length -i) <= phasesMapping[currentPhase].normalLimit,
                    "Normal Phase Limit Exceeded");
                    phasesMapping[currentPhase].normalUserBalance[msg.sender]++;
            } else {
                revert UserPhaseLimitExceeded();
                }
                userMintingLimit--;
                phasesMapping[currentPhase].reservedLimit--;
                UserMapping[msg.sender].limit--;

                _safeMint(msg.sender, tokenId[i]);
                _setTokenURI(tokenId[i], uri[i]);
        }
        emit MintedSuccessfully("NFT Minted Successfully", block.timestamp);
    } 

// /*
// * @dev  admin can mint more than 1 NFT
// * requirements:
// * - length of uri & token Id should be equal
// * - only listed admins can mint
// * - platform minting limit should e greater than zero
// * - token Id should be in the range of total NFT minting limit

// * @param tokenId - user has to add token Id
// * @param uri - metadata hash of the NFT

// * emits a (MintedSuccessfully) event.
// */ 
    function adminMint(string[] memory uri, uint256[] memory tokenId) public whenNotPaused {
        require(
            uri.length == tokenId.length,
            "Invalid Token/URI Length"
        );
        require(
            AdminMapping[msg.sender],
            "Only Admin Can Mint"
        );
        require(
            platformMintingLimit > 0,
            "Limit Exceeded"
        );
       for(uint256 i=0; i < tokenId.length; i++){
           require(
               tokenId[i] > 0 && tokenId[i] <= maxMintingLimit,
               "Token Id out of Range"
           );
       }
        for(uint256 i=0; i < uri.length; i++){
            _safeMint(msg.sender, tokenId[i]);
            _setTokenURI(tokenId[i], uri[i]);

            platformMintingLimit--;
        }
        emit MintedSuccessfully("NFT Minted Successfully", block.timestamp);
    }

// /*
// * @dev  owner can update user global limit per address
// * requirements:
// * - limit to be set should be higher than the current balance of the user
// * - premium user must be verified to get the limit updated
// * - normal user must be registered to get the limit updated

// * @param add - user address
// * @param limit - set the new limit

// * emits a (LimitUpdated) event.
// */     

     function updateGlobal(address[] memory _add, uint256[] memory _limit) public onlyOwner whenNotPaused {
         require(
             _add.length == _limit.length,
             "Invalid Length"
         );

         for(uint256 i = 0; i < _add.length; i++) {
             address user = _add[i];
             uint256 newLimit = _limit[i];

             require(UserMapping[user].isRegistered, "User not registered");
             UserMapping[user].limit = newLimit;
         }
     } 
//   
// /*
// * @dev  owner can update phase limit when its active
// * requirements:
// * - limit to be set should be higher than the current reserved limit
// * - phase should be active
// * - normal user must be registered to get the limit updated

// * @param _lim - set the new limit

// * emits a (LimitUpdated) event.
// */ 
    function updatePhaseLim(uint256 _lim) public onlyOwner whenNotPaused {
        require(
            _lim > phasesMapping[currentPhase].reservedLimit,
            "Limit should be Greater than Current Phase Limit"
            );
        require(
            phasesMapping[currentPhase].isActive,
            "Phase Not Active"
            );
        phasesMapping[currentPhase].reservedLimit = _lim;

        emit LimitUpdated("Phase Limit Updated Successfully", block.timestamp);

    }
// /* 
// * @dev  owner can allow users totransfer their NFTs
// * requirement:
// * - user should not be already allowed

// * emits a (Transfer) event.
// */
    function allowTransfer() public onlyOwner whenNotPaused {
        require(!isTransferrable, "Already Allowed");
        isTransferrable = true;

        emit Transfer("NFT Transfer Allowed", block.timestamp);
    }

// /*
// * @dev  transfer NFTs
// * requirements:
// * - user should be allowed by the owner to transfer the NFTs
// * - other checks already in this function in the library 
// * @param from - user
// * @param to - recipient of the NFT
// * @param tokenId - token to be transferred

// * emits a (Transfer) event from openzeppelin.
// */
    function _transfer(address from, address to, uint256 tokenId) internal override(ERC721) {
        require(isTransferrable, "Not Allowed to Transfer NFT");

        super._transfer(from, to, tokenId);
    } 

// /* 
// * @dev  update metadata hash of NFTs in bulk
// * requirement:
// * - only owner of the NFT can update its token's uri

// * @param struct of bulkNFTs - to update the uri 

// * emits a (UpdatedURI) event.
// */
    function updateURI(bulkNFTs[] memory dataArray) public whenNotPaused {
        for(uint256 i=0; i < dataArray.length; i++)
        if(ownerOf(dataArray[i].id) == msg.sender) {
         _setTokenURI(dataArray[i].id, dataArray[i].uri);

        }

        emit UpdatedURI("URI Updated", block.timestamp);
    }

// /* 
// * @dev  get all NFTs of a user
// * requirement:
// * - user should have NFTs in his account

// * @param _add - user address 
// * @returns token Id and URI
// */
    function fetchNFTs(address _add) public whenNotPaused view returns (bulkNFTs[] memory dataArray) {
        require( 
            balanceOf(_add) > 0, 
            "Invalid Address"
        );
        bulkNFTs[] memory nftsArray = new bulkNFTs[](balanceOf(_add));

        for(uint256 i=0; i < balanceOf(_add); i++){

            uint256 Id= tokenOfOwnerByIndex(_add , i);
            string memory uri = tokenURI(Id);

            nftsArray[i] = bulkNFTs(Id, uri);
        }

        return nftsArray;
    }

    function fetchlimit(address _add) public whenNotPaused view returns (uint256) {
        require(
            UserMapping[_add].isRegistered,
            ""
        );
        return UserMapping[_add].limit;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}