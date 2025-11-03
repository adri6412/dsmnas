# Security Policy

## About This Project

Virtual DSM Bare Metal is a personal project developed and maintained by a single developer in their free time. Please keep this in mind when reporting security issues - responses may take some time, but all reports are taken seriously.

## Supported Versions

| Version | Supported          | Notes                                    |
| ------- | ------------------ | ---------------------------------------- |
| 0.2.x   | :white_check_mark: | Current version - Best effort support    |
| 0.1.x   | :x:                | Legacy version - No longer supported     |
| < 0.1   | :x:                | Pre-release - No support                 |

**Recommendation**: Always use the latest release for the best security and features.

## Reporting a Vulnerability

If you find a security issue, I appreciate your help in making this project safer!

### How to Report

**Please don't create public GitHub issues for security vulnerabilities.**

Instead:
1. **Preferred**: Open a [Security Advisory](https://github.com/adri6412/dsmnas/security/advisories/new) on GitHub (private)
2. **Alternative**: Open a regular issue with title `[SECURITY - Private Details via Email]` and I'll contact you

### What to Include

Help me understand the issue by including:
- Description of the vulnerability
- Steps to reproduce
- Affected files/components
- Potential impact
- Any ideas for a fix (optional but appreciated!)

### Response Time

As this is a side project:
- **Acknowledgment**: I'll try to respond within 1 week
- **Initial Assessment**: Within 2 weeks when possible
- **Fix**: Depends on severity and complexity - could take a few weeks to a couple months
- **Updates**: I'll do my best to keep you informed

I appreciate your patience and understanding!

## Disclosure Timeline

- I prefer to fix issues before they're publicly disclosed
- A reasonable timeline is ~90 days, but I'm flexible depending on severity
- If you need to disclose sooner for any reason, please let me know

## Security Best Practices

### After Installation

**IMPORTANT - Do this first:**
1. ✅ Change default password (`admin/admin`) immediately!
2. ✅ Update to the latest version
3. ✅ Secure your SSH access

### Network Security
- Run behind a firewall or router with port forwarding only for needed services
- Use strong, unique passwords
- Consider using SSH keys instead of passwords
- If exposing to the internet, use a VPN or reverse proxy with HTTPS

### System Hardening
```bash
# Disable root SSH login after setup
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart ssh

# Use SSH keys (recommended)
ssh-copy-id your-user@nas-ip
```

### Updates
- Check for updates regularly on the [Releases page](https://github.com/adri6412/dsmnas/releases)
- Verify SHA256 checksums before installing update packages
- Always backup before major updates
- Review update logs: `/var/log/armnas-auto-update.log`

## Known Limitations

Being a personal project, some security features are not yet implemented:

- ⚠️ No built-in HTTPS (configure reverse proxy if needed)
- ⚠️ No 2FA/MFA support yet
- ⚠️ No formal security audit performed
- ⚠️ Limited automated testing
- ⚠️ Auto-update runs as root (trust your update sources!)

### Recommended Setup for Production

If using in production:
```
Internet → Firewall → Reverse Proxy (HTTPS) → Virtual DSM Bare Metal
```

Use tools like:
- **Cloudflare Tunnel** for secure remote access
- **nginx-proxy-manager** for HTTPS and SSL certificates
- **Tailscale/WireGuard** for VPN access
- **fail2ban** for SSH brute-force protection

## Current Security Features

✅ Password-based authentication for web interface  
✅ Session management with secure cookies  
✅ Admin-only access for system operations  
✅ Update package verification  
✅ Logging of system operations  
✅ ZFS data integrity and snapshots  

## Security Considerations

### Default Credentials
- **Username**: `admin`
- **Password**: `admin`
- ⚠️ **CHANGE THESE IMMEDIATELY** after installation!

### Network Exposure
- Backend API runs on port 8000 (should not be exposed directly)
- Web interface on port 80 (reverse proxy recommended for HTTPS)
- SSH on port 22 (secure it properly!)

### Auto-Update Security
- Update scripts run with root privileges
- Only install update packages from official GitHub releases
- Verify checksums before installation
- Updates are applied at boot time after reboot

## Contributing to Security

If you'd like to help improve security:
- Submit PRs for security improvements
- Suggest security features
- Share security best practices
- Help review code for vulnerabilities

All contributions are welcome and appreciated! 🙏

## Disclaimer

This software is provided "as is" without warranty of any kind. Use at your own risk, especially in production environments. Always maintain backups of important data.

The developer maintains this project in their free time and cannot guarantee immediate security responses, though all reports will be treated seriously.

## Resources

- [GitHub Security Advisories](https://github.com/adri6412/dsmnas/security/advisories)
- [Releases](https://github.com/adri6412/dsmnas/releases)
- [Issues](https://github.com/adri6412/dsmnas/issues)

---

**Last Updated**: November 2025  
**Maintained by**: Single developer (free time project)  
**Response Time**: Best effort - please be patient! 😊
