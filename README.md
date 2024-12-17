# ChainChoice DAO

A decentralized autonomous organization (DAO) implementation featuring quadratic voting and emergency veto mechanisms, built on the Stacks blockchain using Clarity smart contracts.

## Table of Contents
- [Overview](#overview)
- [Features](#features)
- [Smart Contract Architecture](#smart-contract-architecture)
- [Installation](#installation)
- [Usage](#usage)
- [Security Considerations](#security-considerations)
- [Testing](#testing)
- [Contributing](#contributing)

## Overview

ChainChoice DAO is a governance system that implements quadratic voting to ensure fair representation while protecting against whale dominance. It includes an emergency veto system that allows both designated council members and the broader community to halt potentially harmful proposals.

### Key Benefits
- Fair voting weight distribution through quadratic voting
- Protection against malicious proposals via dual-layer veto system
- Transparent and immutable voting records
- Efficient on-chain governance

## Features

### Quadratic Voting System
- Vote weight calculated as square root of tokens committed
- Prevents large token holders from dominating decisions
- Maintains proportional representation while empowering smaller stakeholders

### Emergency Veto System
#### Council Veto
- Requires multiple council members to reach threshold
- Fast-track emergency response
- Controlled by designated council members

#### Community Veto
- Requires 75% of total token supply
- Democratic emergency brake
- Protection against council corruption

### Proposal Management
- Create and track proposals
- Automatic status updates
- Multiple voting stages
- Timelock functionality

## Smart Contract Architecture

### Core Components

1. **Data Storage**
```clarity
(define-map proposals
    {proposal-id: uint}
    {
        creator: principal,
        title: (string-ascii 50),
        description: (string-ascii 500),
        start-block: uint,
        end-block: uint,
        yes-votes: uint,
        no-votes: uint,
        status: (string-ascii 10),
        veto-count: uint,
        is-vetoed: bool
    }
)
```

2. **Access Control**
- Contract owner management
- Council member administration
- Vote validation

3. **Vote Processing**
- Quadratic calculation
- Balance management
- Vote recording

### Constants
```clarity
VETO_THRESHOLD: u750 (75%)
COUNCIL_VETO_THRESHOLD: u2
MAX_TITLE_LENGTH: u50
MAX_DESCRIPTION_LENGTH: u500
```

## Installation

1. Install Clarinet:
```bash
curl -L https://github.com/hirosystems/clarinet/releases/latest/download/clarinet-linux-x64.tar.gz | tar -xz
sudo mv clarinet /usr/local/bin
```

2. Clone the repository:
```bash
git clone https://github.com/your-username/chainchoice-dao.git
cd chainchoice-dao
```

3. Initialize the project:
```bash
clarinet new
```

4. Deploy contracts:
```bash
clarinet deploy
```

## Usage

### Initialize Contract
```clarity
(contract-call? .chainchoice initialize-contract 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 u1000000)
```

### Create Proposal
```clarity
(contract-call? .chainchoice create-proposal "Upgrade Protocol" "Implement new features..." u144)
```

### Vote on Proposal
```clarity
(contract-call? .chainchoice vote u1 u100 true)
```

### Council Veto
```clarity
(contract-call? .chainchoice council-veto u1)
```

### Community Veto
```clarity
(contract-call? .chainchoice community-veto u1)
```

## Security Considerations

1. **Input Validation**
- All user inputs are validated
- String lengths are checked
- Numerical bounds are enforced

2. **Access Control**
- Owner-only functions
- Council member verification
- Balance checks

3. **State Management**
- Atomic operations
- Safe mathematical operations
- Status consistency checks

4. **Known Limitations**
- Block time dependence
- Council centralization risks
- Front-running possibilities

## Testing

Run the test suite:
```bash
clarinet test
```

Test coverage includes:
- Proposal creation
- Voting mechanics
- Veto systems
- Edge cases
- Access control

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Standards
- Follow Clarity best practices
- Add comprehensive tests
- Update documentation
- Use meaningful commit messages


## Contact

Project Link: https://github.com/your-username/chainchoice-dao

## Acknowledgments

- Stacks Foundation
- Clarity Language Team
- DAO Governance Researchers