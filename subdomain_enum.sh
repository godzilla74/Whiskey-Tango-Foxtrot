#!/bin/bash

DOMAIN=`echo $DOMAIN`

if [ -z "$DOMAIN" ]; then
  echo "[!] You must provide a domain name!"
  echo "[!] Example: '-e DOMAIN=example.com'"
  exit
fi

BASE_DIR=/opt/results/$DOMAIN

make_dir() {
  echo "[+] Creating storage directory"
  mkdir -p $BASE_DIR
}

commonspeak() {
  echo "[+] Generating commonspeak wordlist with domain"
  cat /opt/tools/commonspeak2-wordlists/subdomains/subdomains.txt | sed "s/$/.$DOMAIN/" | >> $BASE_DIR/commonspeak.out
  echo "[+] Commonspeak complete! Added $i subdomains"
}

run_amass() {
  echo "[+] Starting amass in passive mode"
  /opt/go/bin/amass enum --passive -d $DOMAIN -o $BASE_DIR/amass.out
  echo "[+] Amass complete!"
}

run_assetfinder() {
  echo "[+] Starting assetfinder with subs-only option"
  /opt/go/bin/assetfinder --subs-only $DOMAIN >> $BASE_DIR/assetfinder.out
  echo "[+] Assetfinder complete!"
}

run_massdns() {
  echo "[+] Starting massdns"
  massdns -r /opt/tools/massdns/lists/resolvers.txt -t A -o S --flush -w $BASE_DIR/massdns.tmp $BASE_DIR/domains.out
  cat $BASE_DIR/massdns.tmp* >> $BASE_DIR/massdns.out
  rm $BASE_DIR/massdns.tmp*
}

run_get_massdns_resolver_offender() {
  echo "[*] Finding offending resolvers"
  cat $BASE_DIR/massdns.out | cut -d " " -f3 | sort >> $BASE_DIR/resolver_offenders.out
  uniq -c $BASE_DIR/resolver_offenders.out | awk '{print $2":"$1}' | sort -nk2 > $BASE_DIR/resolver_offenders.sorted
  rm $BASE_DIR/resolver_offenders.out
  for line in $(cat $BASE_DIR/resolver_offenders.sorted); do
    address=$(echo "$line" | cut -d ":" -f1)
    num=$(echo "$line" | cut -d ":" -f2)
    i=0
    if [ "$num" -gt 5 ]; then
      sed -i "/$address/d" $BASE_DIR/massdns.out
      i=$((i+1))
    fi
  done
  rm $BASE_DIR/resolver_offenders.sorted
  echo "[*] Removed offending resolvers"
}

run_httprobe() {
  echo "[+] Starting httprobe"
  ports="-p http:3000 -p http:4567 -p http:5000  -p http:5104 -p http:8000 -p http:8008 -p http:8080 -p http:8088 -p https:8443 -p http:8280 -p https:8333 -p http:11371 -p http:16080"
  cat $BASE_DIR/subs.out | /opt/go/bin/httprobe $ports | tee -a $BASE_DIR/httprobe.out
  sed -i 's/\.$//' $BASE_DIR/httprobe.out
  sed -i 's/\.:/:/' $BASE_DIR/httprobe.out
  echo "[+] Httprobe complete"
}

run_masscan() {
  echo "[+] Starting masscan"
  masscan -iL $BASE_DIR/ips.out -p0-65535 --rate 1000 -oG $BASE_DIR/masscan.out
  echo "[+] Masscan complete!"
}

run_aquatone() {
  echo "[+] Starting aquatone"
  cat $BASE_DIR/httprobe.out | aquatone -out $BASE_DIR/aquatone -silent
  echo "[+] Aquatone complete!"
}

merge_domains() {
  echo "[*] Merging subdomains into one file"
  sort -u $BASE_DIR/commonspeak.out $BASE_DIR/amass.out $BASE_DIR/assetfinder.out > $BASE_DIR/domains.out
  rm $BASE_DIR/commonspeak.out $BASE_DIR/amass.out $BASE_DIR/assetfinder.out
  echo "[*] Subdomain merge complete!"
}

make_domains() {
  echo "[*] Extracting subdomains from massdns output"
  cat $BASE_DIR/massdns.out | cut -d " " -f1 | sed 's/\.$//' >> $BASE_DIR/subs.out
}

make_ips() {
  echo "[*] Extracting ips from massdns output"
  cat $BASE_DIR/massdns.out | cut -d " " -f3 | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}" >> $BASE_DIR/ips.out
}


make_dir
commonspeak
run_amass
run_assetfinder
merge_domains
run_massdns
run_get_massdns_resolver_offender
make_domains
make_ips
run_httprobe
run_masscan
run_aquatone
