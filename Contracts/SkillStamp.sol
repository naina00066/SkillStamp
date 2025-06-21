// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SkillStamp
 * @dev A decentralized skill verification and certification system
 * @author SkillStamp Team
 */
contract Project {
    
    // Struct to represent a skill certificate
    struct SkillCertificate {
        uint256 id;
        address recipient;
        address issuer;
        string skillName;
        string description;
        uint256 issueDate;
        uint256 expiryDate;
        bool isActive;
        string metadataURI; // IPFS hash for additional certificate data
    }
    
    // Struct for authorized issuers (institutions, organizations)
    struct Issuer {
        string name;
        string description;
        bool isAuthorized;
        uint256 totalCertificatesIssued;
    }
    
    // State variables
    address public owner;
    uint256 private certificateCounter;
    
    // Mappings
    mapping(uint256 => SkillCertificate) public certificates;
    mapping(address => Issuer) public issuers;
    mapping(address => uint256[]) public recipientCertificates;
    mapping(address => uint256[]) public issuerCertificates;
    
    // Events
    event CertificateIssued(
        uint256 indexed certificateId,
        address indexed recipient,
        address indexed issuer,
        string skillName
    );
    
    event IssuerAuthorized(address indexed issuer, string name);
    event IssuerRevoked(address indexed issuer);
    event CertificateRevoked(uint256 indexed certificateId);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }
    
    modifier onlyAuthorizedIssuer() {
        require(issuers[msg.sender].isAuthorized, "Not an authorized issuer");
        _;
    }
    
    modifier certificateExists(uint256 _certificateId) {
        require(certificates[_certificateId].id != 0, "Certificate does not exist");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        certificateCounter = 0;
    }
    
    /**
     * @dev Core Function 1: Issue a new skill certificate
     * @param _recipient Address of the certificate recipient
     * @param _skillName Name of the skill being certified
     * @param _description Description of the skill/achievement
     * @param _validityPeriod Validity period in seconds (0 for no expiry)
     * @param _metadataURI IPFS hash for additional certificate metadata
     */
    function issueCertificate(
        address _recipient,
        string memory _skillName,
        string memory _description,
        uint256 _validityPeriod,
        string memory _metadataURI
    ) external onlyAuthorizedIssuer returns (uint256) {
        require(_recipient != address(0), "Invalid recipient address");
        require(bytes(_skillName).length > 0, "Skill name cannot be empty");
        
        certificateCounter++;
        uint256 newCertificateId = certificateCounter;
        
        uint256 expiryDate = _validityPeriod > 0 ? 
            block.timestamp + _validityPeriod : 0;
        
        certificates[newCertificateId] = SkillCertificate({
            id: newCertificateId,
            recipient: _recipient,
            issuer: msg.sender,
            skillName: _skillName,
            description: _description,
            issueDate: block.timestamp,
            expiryDate: expiryDate,
            isActive: true,
            metadataURI: _metadataURI
        });
        
        recipientCertificates[_recipient].push(newCertificateId);
        issuerCertificates[msg.sender].push(newCertificateId);
        issuers[msg.sender].totalCertificatesIssued++;
        
        emit CertificateIssued(newCertificateId, _recipient, msg.sender, _skillName);
        
        return newCertificateId;
    }
    
    /**
     * @dev Core Function 2: Verify a skill certificate
     * @param _certificateId ID of the certificate to verify
     * @return isValid Whether the certificate is valid
     * @return certificate The certificate details
     */
    function verifyCertificate(uint256 _certificateId) 
        external 
        view 
        certificateExists(_certificateId)
        returns (bool isValid, SkillCertificate memory certificate) 
    {
        certificate = certificates[_certificateId];
        
        // Check if certificate is active and not expired
        isValid = certificate.isActive && 
                 issuers[certificate.issuer].isAuthorized &&
                 (certificate.expiryDate == 0 || certificate.expiryDate > block.timestamp);
        
        return (isValid, certificate);
    }
    
    /**
     * @dev Core Function 3: Authorize or revoke issuer permissions
     * @param _issuer Address of the issuer
     * @param _name Name of the issuing organization
     * @param _description Description of the issuing organization
     * @param _authorize True to authorize, false to revoke
     */
    function manageIssuer(
        address _issuer,
        string memory _name,
        string memory _description,
        bool _authorize
    ) external onlyOwner {
        require(_issuer != address(0), "Invalid issuer address");
        
        if (_authorize) {
            require(bytes(_name).length > 0, "Issuer name cannot be empty");
            
            issuers[_issuer] = Issuer({
                name: _name,
                description: _description,
                isAuthorized: true,
                totalCertificatesIssued: issuers[_issuer].totalCertificatesIssued
            });
            
            emit IssuerAuthorized(_issuer, _name);
        } else {
            issuers[_issuer].isAuthorized = false;
            emit IssuerRevoked(_issuer);
        }
    }
    
    /**
     * @dev Revoke a specific certificate
     * @param _certificateId ID of the certificate to revoke
     */
    function revokeCertificate(uint256 _certificateId) 
        external 
        certificateExists(_certificateId) 
    {
        SkillCertificate storage cert = certificates[_certificateId];
        require(
            msg.sender == cert.issuer || msg.sender == owner,
            "Only issuer or owner can revoke certificate"
        );
        
        cert.isActive = false;
        emit CertificateRevoked(_certificateId);
    }
    
    /**
     * @dev Get all certificates for a recipient
     * @param _recipient Address of the certificate recipient
     * @return Array of certificate IDs
     */
    function getRecipientCertificates(address _recipient) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return recipientCertificates[_recipient];
    }
    
    /**
     * @dev Get all certificates issued by an issuer
     * @param _issuer Address of the issuer
     * @return Array of certificate IDs
     */
    function getIssuerCertificates(address _issuer) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return issuerCertificates[_issuer];
    }
    
    /**
     * @dev Get total number of certificates issued
     * @return Total certificate count
     */
    function getTotalCertificates() external view returns (uint256) {
        return certificateCounter;
    }
    
    /**
     * @dev Check if an address is an authorized issuer
     * @param _issuer Address to check
     * @return Whether the address is an authorized issuer
     */
    function isAuthorizedIssuer(address _issuer) external view returns (bool) {
        return issuers[_issuer].isAuthorized;
    }
}
