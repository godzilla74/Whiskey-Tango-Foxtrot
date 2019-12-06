import os
import sys
import argparse
from subprocess import Popen, PIPE, DEVNULL

#parser = argparse.ArgumentParser(description="Enumerate subdomains for a given domain")
#parser.add_argument('domain', type=str, help='The TLD to enumerate.')
#args = parser.parse_args()

# placeholder for domains list
domain_list = []
# place holder for domain to enumerate
domain = os.environ['DOMAIN']
# placeholder for the outdir strin
outdir = "/opt/results/{}".format(domain)


def make_dir():
    try:
        os.mkdir(outdir)
    except OSError:
        print("[-] Creation of directory {} failed".format(outdir))
    else:
        print("[+] Created storage directory {}".format(outdir))

# Commonspeak generation
def run_commonspeak():
    print("[+] Starting Commonspeak subdomain generation.")
    # holder for domains
    domains = []
    # start commonspeak gen
    wordlist = open('/opt/tools/commonspeak2-wordlists/subdomains/subdomains.txt').read().split('\n')
    for word in wordlist:
        if not word.strip():
            continue
        d = '{}.{}'.format(word.strip(), domain)
        domains.append(d)
    print("[+] Commonspeak created {} subdomain possibilities.".format(len(domains)))
    outfile = open("{}/commonspeak.out".format(outdir),"w+")
    for d in domains:
        outfile.write("{}\n".format(d))
    print("[*] Done!  Results saved to {}/commonspeak.out".format(outdir))
    merge_file("{}/commonspeak.out".format(outdir))


# Rapid7 forward DNS
# TODO: Incomplete ... need to save to file from p.communicate
def run_fdns():
    print("[+] Starting FDNS lookup process ... this will take some time...")
    p = Popen("zcat /opt/fdns/2019-11-23-1574520243-fdns_any.json.gz | grep -F '.{}\"' | jq -r .name | grep '.{}$' | sort | uniq | tee -a {}/fdns.subs".format(domain, domain, outdir), stdout=PIPE, shell=True)
    p.wait()
    merge_file("{}/fdns.subs".format(outdir))
    print("[*] Done! Results saved to {}/fdns.subs".format(outdir))


# bass resolver generation
def run_bass():
    # saving place to go back to
    pwd = os.getcwd()
    print("[+] Starting bass resolver generator.")
    cmd_string = "cd /opt/tools/bass && python3 bass.py -d {} -o {}/{}/resolvers.txt".format(domain, pwd, outdir)
    p = Popen(cmd_string, stdout=DEVNULL, stderr=DEVNULL, shell=True)
    #p.wait()
    # change back to dir
    os.chdir(pwd)
    print("[*] Done!  Results saved to {}/resolvers.txt".format(outdir))


# run amass in passive mode
def run_amass():
    print("[+] Starting amass in passive mode.")
    cmd_string = "/opt/go/bin/amass enum --passive -d {} -o {}/amass.out".format(domain, outdir)
    p = Popen(cmd_string, stdout=DEVNULL, shell=True)
    p.wait()
    merge_file("{}/amass.out".format(outdir))
    print("[*] Done!  Results saved to {}/amass.out".format(outdir))


# merge files
def merge_file(file1):
    print("[+] Merging {}".format(file1))
    # first pass to add to array
    f1 = open(file1).read().split('\n')
    cnt = 0
    for line in f1:
        if not line in domain_list:
            domain_list.append(line)
            cnt += 1
    print("[!] Done.  Added {} domains.".format(cnt))


# write domains to file
def write_domains():
    f = open("{}/domains.tmp".format(outdir), "w+")
    for line in domain_list:
           f.write("{}\n".format(line))


# run massdns with previously generated resolvers list
def run_massdns():
    print("[+] Starting massdns resolving.")
    cmd_string = "massdns -r /opt/tools/massdns/lists/resolvers.txt -t A -o S --flush {}/domains.tmp > {}/massdns.tmp".format(outdir, outdir, outdir)
    # resolvers from bass are jacked up
    #cmd_string = "massdns -r {}/resolvers.txt -t A -o S --flush {}/domains.tmp > {}/massdns.tmp".format(outdir, outdir, outdir)
    p = Popen(cmd_string, stderr=DEVNULL, stdout=PIPE, stdin=PIPE, shell=True)
    p.wait()
#    clean_massdns("{}/massdns.tmp".format(outdir))
    print("[*] Done!  Results saved to {}/massdns.tmp".format(outdir))


# get rid of bogus massdns results
def clean_massdns(file1):
    print("[+] Starting cleanup on massdns")
    ips = {}
    infile = open(file1).read().split('\n')
    for line in infile:
        if line != "":
            if line.split(" ")[2] != "":
                ip = line.split(" ")[2]
                if ip in ips:
                    ips[ip] += 1
                else:
                    ips[ip] = 1
    max_value = max(ips.values())
    max_keys = [k for k, v in ips.items() if v == max_value]
    with open(file1) as ofile, open('{}/massdns.out'.format(outdir), 'w+') as nfile:
        for line in ofile:
            if not any(max_key in line for max_key in max_keys):
                nfile.write(line)
    print("[*] Done!  Cleaned bad resolvers from massdns output!")
    move_mass_results()
    print("[*] Done!  Replaced old/unresolved domain list with live domains")

# remove original domains.tmp
def move_mass_results():
    os.remove("{}/domains.tmp".format(outdir))
    os.rename(r"{}/massdns.out".format(outdir),r"{}/domains.alive".format(outdir))

#
#
#
make_dir()
#run_bass()
run_commonspeak()
run_amass()
write_domains()
run_massdns()
clean_massdns("{}/massdns.tmp".format(outdir))
