---
title: "Basic Penetration Testing Kali Linux"
date: 2025-11-08
draft: false
description: "A very basic automation for testing VPS security externally"
categories: ["Security", "Penetration Testing"]
tags: ["kali-linux", "pentesting", "cybersecurity", "automation", "bash"]
featuredImage: "/images/posts/kali-linux-os-red-5s4vyt83m0scbaq7.webp"
readingTime: true
toc: true
author: "Andrew Jones"
authorImage: "/images/authors/security-team.jpg"
authorBio: "Cybersecurity professionals with 10+ years of experience in penetration testing and ethical hacking"
socialShare: true
---
<br>

# Remote Penetration Testing Guide: Kali Linux

**Hacking your own infrastructure with Kali Linux.** 

This is an example of a script I created for very basic testing to practice my Linux scripting and to make sure my VPS servers remain secure. It is not an in-depth attempt to break things, but it is an attempt to gain more experience with a side of IT that I have little, to no experience in beyond some basic Steganography, which I did in university. Even then that was not related to pen testing but to cryptography. The simple truth is I am lazy and so instead of spending ages collecting all the commands needed to mount an attack / vulnerability scan. I can save a lot of time by automating this process, the below shell script is the result. It works when testing and has given me some ideas. But please be advised it is on the extreme end of simple. 

But if you have an open port, it will find it and report what when why how, etc. 
I will be doing a post on Steganography at some point but it is a complex subject to talk about, if hacking is about picking locks and gaining access then Steganography is about the opposite. 


The script has been tested inside a VM and within a devcontainer—it's always recommended to test automation before letting it run loose in a production environment. I used different containers because I wanted to test some of the flags by removing various APT packages and see if they would be picked up and print warnings about the missing dependencies.

 > <a href="https://cisofy.com/lynis/" class="external-link" target="_blank" rel="noopener">Lynis</a> Please use this link to explore Lynis and run you own audits. 

Taking these kinds of precautions is how you can make a real attempt at keeping yourself somewhat safe. I'll do a real deep dive on Lynis later, as I use it a lot when I update applications or daemons. It gives you good view on the current state of you endpoint security, though it's hard to get 100%, even if you could the restriction on the system would, in my opinion, make it hard to interact with as an administrator.  

# Overview

Remote penetration testing is the process of evaluating the security of computer systems, networks, and applications from an external perspective. Kali Linux provides the ultimate toolkit for security professionals to identify vulnerabilities before malicious actors can exploit them.

### Why Use Kali Linux for Penetration Testing?

- **Comprehensive Toolset**: 600+ pre-installed security tools
- **Professional Framework**: Industry-standard methodologies and workflows
- **Regular Updates**: Continuous security tool updates and maintenance
- **Community Support**: Active community and extensive documentation

## Prerequisites

Before you begin, ensure you have the following:

- Kali Linux 2023.x or newer installed
- Legal authorization to test the target systems
- Basic understanding of networking and Linux commands
- Proper scope definition and rules of engagement


```bash
#!/bin/bash

# Automated Penetration Testing Script
# Usage: ./scan.sh <target_ip>

if [ $# -eq 0 ]; then
    echo "Usage: $0 <target_ip>"
    exit 1
fi

TARGET=$1
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="pentest_${TARGET}_${TIMESTAMP}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Create output directory with absolute path
OUTPUT_DIR="$(pwd)/${OUTPUT_DIR}"
REPORT="${OUTPUT_DIR}/REPORT.txt"
mkdir -p $OUTPUT_DIR
cd $OUTPUT_DIR

echo -e "${GREEN}[*] Starting automated penetration test${NC}"
echo -e "${GREEN}[*] Target: $TARGET${NC}"
echo -e "${GREEN}[*] Output: $OUTPUT_DIR${NC}"
echo ""

# Initialize report
cat > $REPORT << EOF
===============================================
PENETRATION TEST REPORT
===============================================
Target: $TARGET
Date: $(date)
Tester: $(whoami)
===============================================

EOF

# Function to log
log_section() {
    echo -e "\n$1\n" | tee -a $REPORT
    echo "===============================================" | tee -a $REPORT
}

# Function to run command and log
run_and_log() {
    local cmd=$1
    local desc=$2
    echo -e "${YELLOW}[+] $desc${NC}"
    echo -e "\n## $desc\n" >> $REPORT
    echo "\$ $cmd" >> $REPORT
    eval $cmd >> $REPORT 2>&1
    echo -e "${GREEN}[✓] Complete${NC}"
}

# 1. RECONNAISSANCE
log_section "PHASE 1: RECONNAISSANCE"

run_and_log "ping -c 3 $TARGET" "Host Reachability"

run_and_log "nmap -sn $TARGET" "Host Discovery"

run_and_log "nmap -sS -p- --min-rate=1000 -T4 $TARGET -oN nmap_full_scan.txt" "Full Port Scan"

# Extract open ports
OPEN_PORTS=$(grep "open" nmap_full_scan.txt | cut -d'/' -f1 | paste -sd,)
echo "Open ports: $OPEN_PORTS" | tee -a $REPORT

if [ ! -z "$OPEN_PORTS" ]; then
    run_and_log "nmap -sV -sC -p$OPEN_PORTS $TARGET -oN nmap_detailed.txt" "Service Enumeration"
    
    run_and_log "nmap -O $TARGET -oN nmap_os_detection.txt" "OS Detection"
fi

# 2. VULNERABILITY SCANNING
log_section "PHASE 2: VULNERABILITY SCANNING"

run_and_log "nmap --script vuln -p$OPEN_PORTS $TARGET -oN nmap_vuln_scan.txt" "Nmap Vulnerability Scripts"

run_and_log "nmap --script ssl-enum-ciphers -p 443,8443 $TARGET -oN ssl_scan.txt" "SSL/TLS Analysis"

# 3. WEB ENUMERATION
if echo $OPEN_PORTS | grep -qE "80|443|8080|8443"; then
    log_section "PHASE 3: WEB APPLICATION TESTING"
    
    # Determine protocol
    if echo $OPEN_PORTS | grep -q "443\|8443"; then
        PROTO="https"
    else
        PROTO="http"
    fi
    
    TARGET_URL="${PROTO}://${TARGET}"
    
    run_and_log "whatweb $TARGET_URL" "Web Technology Detection"
    
    run_and_log "nikto -h $TARGET_URL -o nikto_scan.txt" "Nikto Web Scan"
    
    run_and_log "gobuster dir -u $TARGET_URL -w /usr/share/wordlists/dirb/common.txt -o gobuster_scan.txt -q" "Directory Enumeration"
    
    # Nuclei scan if installed
    if command -v nuclei &> /dev/null; then
        run_and_log "nuclei -u $TARGET_URL -severity critical,high,medium -o nuclei_scan.txt" "Nuclei Vulnerability Scan"
    fi
    
    # Check for common CMS
    if grep -qi "wordpress" whatweb_output.txt 2>/dev/null || curl -s $TARGET_URL | grep -qi "wp-content"; then
        run_and_log "wpscan --url $TARGET_URL --enumerate vp,vt,u --no-banner -o wpscan.txt" "WordPress Scan"
    fi
fi

# 4. SERVICE-SPECIFIC TESTS
log_section "PHASE 4: SERVICE-SPECIFIC ENUMERATION"

# SSH
if echo $OPEN_PORTS | grep -q "22"; then
    run_and_log "nmap --script ssh2-enum-algos,ssh-auth-methods -p 22 $TARGET -oN ssh_enum.txt" "SSH Enumeration"
fi

# FTP
if echo $OPEN_PORTS | grep -q "21"; then
    run_and_log "nmap --script ftp-anon,ftp-bounce,ftp-libopie,ftp-proftpd-backdoor,ftp-syst -p 21 $TARGET -oN ftp_enum.txt" "FTP Enumeration"
fi

# SMB
if echo $OPEN_PORTS | grep -qE "139|445"; then
    run_and_log "nmap --script smb-enum-shares,smb-enum-users,smb-os-discovery -p 139,445 $TARGET -oN smb_enum.txt" "SMB Enumeration"
    
    if command -v enum4linux &> /dev/null; then
        run_and_log "enum4linux -a $TARGET" "Enum4linux Scan"
    fi
fi

# MySQL
if echo $OPEN_PORTS | grep -q "3306"; then
    run_and_log "nmap --script mysql-info,mysql-enum -p 3306 $TARGET -oN mysql_enum.txt" "MySQL Enumeration"
fi

# 5. GENERATE SUMMARY
log_section "PHASE 5: SUMMARY AND FINDINGS"

echo "Scan Statistics:" | tee -a $REPORT
echo "- Open Ports: $(echo $OPEN_PORTS | tr ',' ' ' | wc -w)" | tee -a $REPORT
echo "- Services Identified: $(grep -c "open" nmap_detailed.txt 2>/dev/null || echo 0)" | tee -a $REPORT
echo "" | tee -a $REPORT

echo "Critical Findings:" | tee -a $REPORT
grep -i "VULNERABLE\|CVE-\|critical\|high" *.txt 2>/dev/null | head -20 | tee -a $REPORT

echo "" | tee -a $REPORT
echo "All scan outputs saved to: $OUTPUT_DIR" | tee -a $REPORT
echo "Main report: $REPORT" | tee -a $REPORT

# Create HTML summary
cat > summary.html << HTMLEOF
<!DOCTYPE html>
<html>
<head>
    <title>Pentest Report - $TARGET</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f4f4f4; }
        .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #4CAF50; padding-bottom: 10px; }
        h2 { color: #666; margin-top: 30px; }
        .info { background: #e8f5e9; padding: 15px; border-left: 4px solid #4CAF50; margin: 20px 0; }
        .warning { background: #fff3cd; padding: 15px; border-left: 4px solid #ffc107; margin: 20px 0; }
        .critical { background: #f8d7da; padding: 15px; border-left: 4px solid #dc3545; margin: 20px 0; }
        pre { background: #f8f9fa; padding: 15px; border-radius: 4px; overflow-x: auto; }
        .port { display: inline-block; background: #007bff; color: white; padding: 5px 10px; margin: 5px; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Penetration Test Report</h1>
        <div class="info">
            <strong>Target:</strong> $TARGET<br>
            <strong>Date:</strong> $(date)<br>
            <strong>Tester:</strong> $(whoami)
        </div>
        
        <h2>Open Ports</h2>
        <div>
$(for port in $(echo $OPEN_PORTS | tr ',' ' '); do echo "<span class='port'>$port</span>"; done)
        </div>
        
        <h2>Services Detected</h2>
        <pre>$(grep "open" nmap_detailed.txt 2>/dev/null | head -20)</pre>
        
        <h2>Vulnerabilities</h2>
        <div class="critical">
        <pre>$(grep -i "VULNERABLE\|CVE-" *.txt 2>/dev/null | head -20)</pre>
        </div>
        
        <h2>Full Report</h2>
        <p>See <strong>REPORT.txt</strong> for complete details and command outputs.</p>
    </div>
</body>
</html>
HTMLEOF

echo ""
echo -e "${GREEN}[✓] Scan Complete!${NC}"
echo -e "${GREEN}[*] HTML Report: ${OUTPUT_DIR}/summary.html${NC}"
echo -e "${GREEN}[*] Text Report: ${OUTPUT_DIR}/REPORT.txt${NC}"
echo ""

```
## Instalation 

- See the below for command list (Kali comes out of the box with all of what you need)
```bash
sudo apt update && upgrade -y [post update should update all tools]

```
```bash
# Verify Kali Linux version
cat /etc/os-release
lsb_release -a

# Check essential tools
which nmap
which nikto
which gobuster
Key Features
Automated Reconnaissance
Comprehensive host discovery, port scanning, and service enumeration using industry-standard tools like Nmap.

Vulnerability Assessment
Automated and manual vulnerability identification using specialized scanners and custom scripts.

Web Application Testing
Specialized tools for web application security testing, including directory brute-forcing and vulnerability scanning.

## Installation & Setup ##

Step 1: Update Kali Linux
bash
# Update system and tools
sudo apt update && sudo apt upgrade -y
sudo apt full-upgrade -y

# Install additional tools (if needed)
sudo apt install seclists gobuster nikto wpscan sqlmap -y
Step 2: Prepare Testing Environment
bash
# Create working directory
mkdir -p ~/pentesting/projects
cd ~/pentesting/projects

# Set up project structure
mkdir {reconnaissance,vulnerability,exploitation,reporting}
Step 3: Verify Tools Installation
bash
# Check critical tools
nmap --version
nikto -Version
gobuster version
Configuration Options
Option	Description	Default	Example
Scan Intensity	Aggressiveness of scans	-T4	-T5
Port Range	Ports to scan	--top-ports 1000	-p- (all ports)
Wordlists	Directory/file wordlists	common.txt	directory-list-2.3-medium.txt
Output Format	Report formats	-oN (normal)	-oA (all formats)
Configuration File Example
bash

# pentest_config.conf
TARGET_RANGE="192.168.1.0/24"
SCAN_INTENSITY="T4"
TOP_PORTS="1000"
WORDLIST_DIR="/usr/share/wordlists/dirbuster"
OUTPUT_FORMATS="-oA"
Usage Examples
Basic Usage
Start with the automated penetration testing script:

bash
# Make script executable
chmod +x scan.sh

# Run basic scan
./scan.sh 192.168.1.100
Expected output:

text
[*] Starting automated penetration test
[*] Target: 192.168.1.100
[*] Output: /home/kali/pentest_192.168.1.100_20251108_1430
[+] Host Reachability
[✓] Complete
Intermediate Usage

```

            

 ```bash
# Built-in help
nmap --help
man nmap

# Tool documentation
nikto -H
gobuster --help

# Online resources
- [Kali Linux Documentation](https://www.kali.org/docs/)
- [Nmap Reference Guide](https://nmap.org/book/man.html)
- [OWASP Testing Guide](https://owasp.org/www-project-web-security-testing-guide/) 
```      
## Additional Resources

### Official Documentation
- [Kali Linux Official Docs](https://www.kali.org/docs/)
- [Nmap Reference Guide](https://nmap.org/book/)
- [OWASP Testing Guide](https://owasp.org/www-project-web-security-testing-guide/)

### Community Resources
- [Kali Linux Forums](https://forums.kali.org/)
- [Reddit r/netsec](https://reddit.com/r/netsec)
- [Stack Overflow Security](https://stackoverflow.com/questions/tagged/security)

### Related Tools
- **Nessus**: Comprehensive vulnerability scanner
- **Burp Suite Professional**: Advanced web application testing
- **Metasploit Pro**: Commercial penetration testing platform

### Further Reading
- [Penetration Testing Execution Standard](http://www.pentest-standard.org/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [SANS Penetration Testing Resources](https://www.sans.org/cyber-security-courses/penetration-testing/)

## Conclusion

This comprehensive guide has equipped you with the knowledge and tools to conduct professional remote penetration tests using Kali Linux. From automated reconnaissance to detailed vulnerability assessment, you now have a complete methodology for identifying and documenting security weaknesses.

### What's Next?

- Explore advanced exploitation techniques with Metasploit
- Learn web application security testing in depth
- Study network forensics and incident response
- Pursue professional certifications like OSCP or CEH

---

*Last updated: 2025-11-08*

*Found an error or have a suggestion? [Please open an issue](https://github.com/StoicTurk182/Blog) or submit a pull request.*

---

### Notes for Content Creators

**Testing & Compatibility:**
- All commands have been tested on Kali Linux 2023.3
- Script assumes standard Kali tool locations
- Always verify authorization before running scans
- Consider organizational policies and compliance requirements
- Update wordlist paths based on your Kali installation

**SEO Considerations:**
- Primary keyword: "Kali Linux penetration testing"
- Secondary keywords: "remote security assessment", "automated penetration testing"
- Meta description optimized for security professionals

**Master the art of ethical hacking with this comprehensive guide to remote penetration testing using Kali Linux.** This guide provides security professionals, system administrators, and ethical hackers with a complete methodology for assessing remote system security, complete with automated scripts and real-world examples.

> ⚠️ **IMPORTANT SECURITY DISCLAIMER**
> 
> This guide is for **educational and authorized testing purposes only**. Unauthorized scanning and testing may be **illegal in your jurisdiction**. Always obtain **proper written permissions** and follow **ethical hacking guidelines** before conducting any security assessments.
