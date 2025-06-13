# SummitEthic Mailcow Infrastructure

## Overview

This repository contains the Ansible automation for deploying and managing SummitEthic's email infrastructure using Mailcow, Traefik, and the Grafana monitoring stack. The implementation follows DevOps best practices with a strong emphasis on security, reliability, and ethical considerations.

## Architecture

- **Mailcow**: Dockerized email server suite
- **Traefik**: Reverse proxy with automatic HTTPS
- **Grafana Stack**: Prometheus, Grafana, Loki, and AlertManager for comprehensive monitoring
- **Security**: Multi-layered security following NIST SP 800-53 and CIS benchmarks

## Prerequisites

- Ansible 2.9+
- Ubuntu Server 22.04 LTS
- Docker and Docker Compose
- Valid domain with Cloudflare DNS

## Quick Start

1. Clone this repository
2. Copy `inventories/production/hosts.yml.example` to `inventories/production/hosts.yml`
3. Update inventory with your server details
4. Create vault password file
5. Run the playbook:

```bash
ansible-playbook -i inventories/production/hosts.yml playbooks/site.yml --ask-vault-pass
```

## Directory Structure

```
ansible-mailcow/
├── inventories/          # Environment-specific configurations
├── roles/               # Ansible roles for each component
├── playbooks/           # Orchestration playbooks
├── templates/           # Jinja2 templates
├── files/              # Static files
└── tests/              # Testing scripts
```

## Security Considerations

- All secrets are managed using Ansible Vault
- SSH key-based authentication only
- Automated security updates enabled
- Comprehensive firewall rules
- Fail2ban for intrusion prevention
- Regular automated backups

## Monitoring

Access monitoring dashboards:
- Grafana: https://grafana.mail.summitethic.com
- Prometheus: https://prometheus.mail.summitethic.com (internal only)
- AlertManager: https://alerts.mail.summitethic.com (internal only)

## Ethical Compliance

This infrastructure implementation adheres to:
- IEEE/ACM Code of Ethics
- GDPR requirements for email systems
- Privacy-by-design principles
- Transparent logging and auditing

## Contributing

Please read CONTRIBUTING.md for our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support, email devops@summitethic.com or create an issue in this repository.