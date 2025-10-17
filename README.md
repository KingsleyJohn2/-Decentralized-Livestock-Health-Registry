A blockchain-powered solution for tracking livestock health records, ownership, and enabling secure marketplace transactions with built-in micro-insurance.

## 🎯 Problem Solved

- 🦠 **Disease Control**: Prevents livestock disease outbreaks through coordinated health tracking
- 📋 **Proof of Health**: Provides verifiable vaccination and health history for market transactions
- 💰 **Insurance Protection**: Automated payouts for livestock illness/death events
- 🏪 **Trusted Marketplace**: Verified healthy livestock trading platform

## ⚡ Key Features

- 🏷️ **NFT-Based Identity**: Each animal gets a unique digital identity linked to ear tags/biometrics
- 👨‍⚕️ **Veterinarian-Only Updates**: Only licensed vets can add health records
- 🛡️ **Micro-Insurance**: Escrow-based insurance claims with veterinarian verification
- 🛒 **Verified Marketplace**: Trade livestock with transparent health status
- 💀 **Mortality Tracking**: Comprehensive death reporting and verification system

## 🚀 Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing

### Installation

```bash
git clone <repository-url>
cd Decentralized-Livestock-Health-Registry
clarinet check
```

## 📖 Contract Functions

### 🏥 Veterinarian Management

**Register Veterinarian** (Contract Owner Only)
```clarity
(contract-call? .livestock-registry register-veterinarian "VET123456" "Large Animal Specialist")
```

### 🐮 Livestock Registration

**Register New Livestock**
```clarity
(contract-call? .livestock-registry register-livestock 
  "Cattle" 
  "Holstein" 
  u20220101 
  "TAG001" 
  0x1234567890abcdef1234567890abcdef12345678 
  u50000 
  u10000)
```

### 📋 Health Records

**Add Health Record** (Veterinarians Only)
```clarity
(contract-call? .livestock-registry add-health-record 
  u1 
  "vaccination" 
  "Annual FMD vaccination administered" 
  (some "Foot-and-Mouth Disease Vaccine") 
  (some u365) 
  u2)
```

### 🏪 Marketplace Operations

**List Livestock for Sale**
```clarity
(contract-call? .livestock-registry list-for-sale u1 u45000 "STX")
```

**Purchase Livestock**
```clarity
(contract-call? .livestock-registry purchase-livestock u1)
```

### 🛡️ Insurance System

**Contribute to Insurance Pool**
```clarity
(contract-call? .livestock-registry contribute-to-insurance-pool u1000)
```

**File Insurance Claim**
```clarity
(contract-call? .livestock-registry file-insurance-claim u1 "death" u8000)
```

**Verify Claim** (Veterinarians Only)
```clarity
(contract-call? .livestock-registry verify-insurance-claim u1 true)
```

## 🔍 Read-Only Functions

### Query Livestock Information
```clarity
(contract-call? .livestock-registry get-livestock-info u1)
(contract-call? .livestock-registry get-health-record u1 u0)
(contract-call? .livestock-registry get-marketplace-listing u1)
(contract-call? .livestock-registry get-insurance-claim u1)
```

### Check System Status
```clarity
(contract-call? .livestock-registry get-insurance-pool-balance)
(contract-call? .livestock-registry get-next-livestock-id)
(contract-call? .livestock-registry get-livestock-owner u1)
```

## 🏗️ Data Structure

### Livestock Registry
- **Owner**: Principal address
- **Species & Breed**: Animal classification
- **Birth Date**: Timestamp
- **Ear Tag ID**: Physical identifier
- **Biometric Hash**: Unique biological identifier
- **Health Status**: Current condition (healthy/moderate/critical)
- **Market Value**: Economic worth
- **Insurance Amount**: Coverage limit

### Health Records
- **Veterinarian**: Licensed practitioner
- **Record Type**: vaccination/treatment/checkup
- **Description**: Detailed notes
- **Vaccination Name**: Specific vaccine (optional)
- **Treatment Date**: When performed
- **Next Checkup**: Scheduled follow-up
- **Severity**: 1-10 scale
- **Verified**: Veterinarian confirmation

### Mortality Records
- **Reported By**: Livestock owner
- **Cause**: Reason for death (up to 100 characters)
- **Reported Date**: Timestamp of report
- **Verified**: Veterinarian confirmation status
- **Verified By**: Veterinarian principal (optional)

## 🧪 Testing

```bash
clarinet test
```

## 🚚 Livestock Transport Tracking

**Record Transport** (Livestock Owners Only)
```clarity
(contract-call? .livestock-registry record-transport
  u1
  "Farm A to Market B"
  "sale")
```

**Verify Transport** (Veterinarians Only)
```clarity
(contract-call? .livestock-registry verify-transport u1 u0)
```

**Get Transport Record**
```clarity
(contract-call? .livestock-registry get-transport-record u1 u0)
```

## 💀 Livestock Mortality Reporting

**Report Mortality** (Livestock Owners Only)
```clarity
(contract-call? .livestock-registry report-mortality
  u1
  "Natural causes - old age")
```

**Verify Mortality** (Veterinarians Only)
```clarity
(contract-call? .livestock-registry verify-mortality u1)
```

**Get Mortality Record**
```clarity
(contract-call? .livestock-registry get-mortality-record u1)
```

## � Security Features

- ✅ **Access Control**: Role-based permissions for veterinarians
- ✅ **Ownership Verification**: NFT-based ownership checks
- ✅ **Financial Safety**: Amount validation and balance checks
- ✅ **Data Integrity**: Immutable health records
- ✅ **Insurance Protection**: Veterinarian-verified claims only

## 🎯 Use Cases

1. **👨‍🌾 Farmers**: Track animal health, prove vaccination status, access insurance
2. **👨‍⚕️ Veterinarians**: Maintain digital health records, verify insurance claims
3. **🏪 Buyers**: Purchase livestock with verified health history
4. **🏛️ Authorities**: Monitor disease outbreaks, ensure food safety

## 📊 Error Codes

- **100**: Not authorized
- **101**: Record not found
- **102**: Already exists
- **103**: Invalid amount
- **104**: Not owner
- **105**: Not veterinarian
- **106**: Insufficient funds
- **107**: Invalid status
- **108**: Claim already exists
- **109**: Already rated
- **110**: Invalid rating
- **111**: No purchase record
- **112**: Already deceased

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Submit pull request with tests

## 📄 License

MIT License - Build the future of livestock management! 🚀
