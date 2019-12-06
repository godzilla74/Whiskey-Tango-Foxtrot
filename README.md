# pentest-tools
Automated framework to do stuff

# What happens:
1.  Generates a subdomain wordlist with `commonspeak2-wordlists`
2.  Runs `amass` in passive mode on the domain provided
3.  Merges `commonspeak` and `amass` domains
4.  Resolves domains with `massdns`
5.  Outputs the resolved hosts to `domains.alive`

# Results:
You'll get a list of domains and the resolved IP/CNAME.  Such as:
```
ie.conv.indeed.com. CNAME europe.dyn.indeed.com.
gb.conv.indeed.com. CNAME europe.dyn.indeed.com.
ph.conv.indeed.com. CNAME eastasian.dyn.indeed.com.
```

# Usage:
** Make sure you change the DOMAIN variable in `docker run`**
```
git clone git@github.com:godzilla74/pentest-tools.git
cd pentest-tools
docker build -t recon .
docker run -it -v $(pwd):/opt/results -e DOMAIN=example.com recon
```

# Todo
- [x]  dockerize
- [ ]  masscan the resulting IPs  
- [ ]  add user mount for wordlists
- [ ]  ffuf the domains - directory brute force    
- [x]  add assetfinder to the mix
- [ ]  add meg
- [ ]  add aquatone
