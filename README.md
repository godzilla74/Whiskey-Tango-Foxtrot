# Whiskey-Tango-Foxtrot
Automated framework to do big bounty recon

## What happens:
1.  Generates a subdomain wordlist with `commonspeak2-wordlists`
2.  Runs `amass` in passive mode on the domain provided
3.  Merges `commonspeak` and `amass` domains
4.  Resolves domains with `massdns`
5.  Outputs the resolved hosts to `domains.tmp`
6.  Runs `httprobe` on the resolved subdomains
7.  Runs `masscan` on the resolved ips
8.  Runs `aquatone` on the subdomains that `httprobe` found to be alive
9.  Runs `ffuf` on the found domains `...domain.com/FUZZ`

## Results:
You'll get a few files.  I decided it's best to let you figure out what you want to keep:
-  `domains.out`: The unique list of domains from `commonspeak`, `assetfinder`, and `amass`
-  `massdns.out`: The results of `massdns` (subdomains & resolved IPs)
-  `httprobe.out`: The results of `httprobe` (subdomains that responded to ports 3000,4567,5000,5104,8000,8008,8080,8088,8443,8280,8333,11371,16080)
-  `masscan.out`: The results of `masscan` (provided in greppable format)
-  `ips.out`: Results of `massdns` with only the ip addresses
-  `subs.out`: Results of `massdns` with only the subdomains
-  `ffuf.out`: Results of `ffuf` with only `status code` and `url`
-  `aquatone/`: Directory of the `aquatone` results
-  `ffuf/`: Directory containing ffuf fuzzed directories

## Usage:
There are some variables you need to pass:
-  `<domain>`: is the TLD or subdomain you want to run against (Ex:  domain.com).
-  `<resolver_check>`: is either `true` or `false`.  If you notice that you're not getting any final output set this value to `false` to disable the offending resolver check from massdns.
-  `<wordlist_size>`: is either `large` or `small`.

```
git clone git@github.com:godzilla74/pentest-tools.git
cd pentest-tools
docker build -t recon .
docker run -it -v $(pwd):/opt/results recon <domain> <resolver_check> <wordlist_size>
```

## Todo:
- [x]  dockerize
- [x]  masscan the resulting IPs  
- [ ]  add user mount for wordlists
- [x]  ffuf the domains - directory brute force    
- [x]  add assetfinder to the mix
- [ ]  add meg
- [x]  add aquatone
- [x]  add httprobe
- [ ]  massdns CNAME results into their own file (for subdomain takeover?)
- [ ]  add `parallel` support to run some jobs in tandem (masscan, httprobe, aquatone)

## Problems or Suggestions:
Have a problem or suggestion?  [Make an issue](https://github.com/godzilla74/pentest-tools/issues).  I might get to it:
