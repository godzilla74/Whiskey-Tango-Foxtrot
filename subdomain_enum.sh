#!/bin/bash

DOMAIN=$1
RES_CHECK=$2
WORDLIST=$3

# get the domain name provided
# TODO: add a sanity/validation check here to make sure a domain was acutally passed
if [ -z "$DOMAIN" ]; then
  echo "[!] You must provide a domain name!"
  echo "[!] Example: 'docker run -it -v \$(pwd):/opt/results recon example.com false'"
  exit
fi

# Sometimes the massdns resolvers are actually correct
# So, providing an option to disable that function
# TODO: add a sanity/validation check for true/false being passed
if [ -z "$RES_CHECK" ]; then
  echo "[!] You must specify if you want the resolver check to run!"
  echo "[!] Example: 'docker run -it -v \$(pwd):/opt/results recon example.com false'"
fi

# figure out which wordlist to use
if [ -z "$WORDLIST" ]; then
  echo "[!] No wordlist provided, using small (dicc) wordlist."
  WORDLIST="/opt/wordlists/dicc.txt"
elif [ "$WORDLIST" == "large" ]; then
  echo "[!] Using large (raft) wordlist."
  WORDLIST="/opt/wordlists/raft-all.txt"
elif [ "$WORDLIST" == "small" ]; then
  echo "[!] Using small (dicc) wordlist."
  WORDLIST="/opt/wordlists/dicc.txt"
else
  echo "[!] Not sure what you provided, using small (dicc) wordlist."
  WORDLIST="/opt/wordlists/dicc.txt"
fi

BASE_DIR=$DOMAIN

make_dir() {
  mkdir -p $BASE_DIR
}

commonspeak() {
  echo "[+] Generating commonspeak wordlist with domain"
  cat /opt/tools/commonspeak2-wordlists/subdomains/subdomains.txt | sed "s/$/\.$DOMAIN/" | tee -a $BASE_DIR/commonspeak.out
  echo "[+] Commonspeak complete!"
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
  massdns -r /opt/tools/massdns/lists/resolvers.txt -t A -o S --flush -w $BASE_DIR/massdns.out $BASE_DIR/domains.out
  echo "[+] Massdns complete!"
}

run_get_massdns_resolver_offender() {
  if [ "$RES_CHECK" = true ]; then
    echo "[*] Finding offending resolvers"
    cat $BASE_DIR/massdns.out | cut -d " " -f3 | sort >> $BASE_DIR/resolver_offenders.out
    uniq -c $BASE_DIR/resolver_offenders.out | awk '{print $2":"$1}' | sort -nk2 > $BASE_DIR/resolver_offenders.sorted
    rm $BASE_DIR/resolver_offenders.out
    i=0
    for line in $(cat $BASE_DIR/resolver_offenders.sorted); do
      address=$(echo "$line" | cut -d ":" -f1)
      num=$(echo "$line" | cut -d ":" -f2)
      if [ "$num" -gt 10 ]; then
        sed -i "/$address/d" $BASE_DIR/massdns.out
        echo "[!] Removing offender $address from massdns results."
        i=$((i+1))
      fi
    done
    rm $BASE_DIR/resolver_offenders.sorted
    echo "[*] Removed $i offending resolvers"
  else
    echo "[!] Not performing resolver check since it was disabled"
  fi
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
  masscan -iL $BASE_DIR/ips.out -p0-65535 --banners --max-rate 10000 -oG $BASE_DIR/masscan.out
  echo "[+] Masscan complete!"
}

run_aquatone() {
  echo "[+] Starting aquatone"
  cat $BASE_DIR/httprobe.out | aquatone -out $BASE_DIR/aquatone -silent
  echo "[+] Aquatone complete!"
}

run_ffuf() {
  if [ ! -d "$BASE_DIR/ffuf" ]; then
    mkdir $BASE_DIR/ffuf
  fi
  for line in $(cat $BASE_DIR/subs.out); do
    http=`grep -oP "http:\/\/$line" $BASE_DIR/httprobe.out | wc -l`
    https=`grep -oP "https:\/\/$line" $BASE_DIR/httprobe.out | wc -l`
    if [ "$https" -eq 1 ]; then
      ffuf -ac -u https://$line/FUZZ -w $WORDLIST -o $BASE_DIR/ffuf/$line -of json
    else
      ffuf -ac -u http://$line/FUZZ -w $WORDLIST -o $BASE_DIR/ffuf/$line -of json
    fi
  done
  echo "[+] Parsing all ffuf results into ffuf.out"
  cat $BASE_DIR/ffuf/* | jq '[.results[]|{status: .status, url: .url}]' | grep -oP "status\":\s(\d{3})|url\":\s\"(http[s]?:\/\/.*?)\"" | paste -d' ' - - | awk '{print $2" "$4}' | sed 's/\"//g' >> $BASE_DIR/ffuf.out
  echo "[+] FFUF complete!"
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
  sort $BASE_DIR/subs.out | uniq >> $BASE_DIR/subs.sorted
  mv $BASE_DIR/subs.sorted $BASE_DIR/subs.out
}

make_ips() {
  echo "[*] Extracting ips from massdns output"
  cat $BASE_DIR/massdns.out | cut -d " " -f3 | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}" >> $BASE_DIR/ips.out
  sort $BASE_DIR/ips.out | uniq >> $BASE_DIR/ips.sorted
  mv $BASE_DIR/ips.sorted $BASE_DIR/ips.out
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
run_ffuf
