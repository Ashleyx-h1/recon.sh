#!/bin/bash
set -euo pipefail

# ----------------------------
# Input
# ----------------------------
echo "Enter target domain (example.com):"
read -r target

timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
outdir="recon_${target}_${timestamp}"

mkdir -p "$outdir"
cd "$outdir" || exit

echo "[+] Output folder: $outdir"

# ----------------------------
# Subdomain Enumeration
# ----------------------------
echo "[+] Running subfinder..."
echo "$target" | subfinder -silent -all | dnsx -silent -threads 100 | sort -u > subfinder_results.txt

# ----------------------------
# Live domain probing
# ----------------------------
echo "[+] Probing live domains with httpx-toolkit..."
cat subfinder_results.txt | httpx-toolkit -sc -td -cl -server -location -cname -title -silent > live_domains.txt

# ----------------------------
# Port scanning
# ----------------------------
echo "[+] Running naabu port scan..."
cat subfinder_results.txt | naabu -silent > naabu_results.txt

# ----------------------------
# Activate virtualenv
# ----------------------------
if [ -f ~/venv/bin/activate ]; then
    source ~/venv/bin/activate
else
    echo "[!] Virtualenv not found. Tools like uro may fail."
fi

# ----------------------------
# URL collection
# ----------------------------
echo "[+] Collecting URLs using gau..."
echo "$target" | gau --subs | uro > gau_results.txt

echo "[+] Collecting URLs using waybackurls..."
echo "$target" | waybackurls | uro > waybackurls_results.txt

echo "[+] Crawling with katana..."
echo "$target" | katana -d 5 -jc -silent | uro > katana_results.txt

# ----------------------------
# Merge all URLs
# ----------------------------
echo "[+] Merging all URLs..."
cat gau_results.txt waybackurls_results.txt katana_results.txt | sort -u | uro > all_urls.txt

# Clean temporary files
rm -f gau_results.txt waybackurls_results.txt katana_results.txt

# ----------------------------
# XSS scanning
# ----------------------------
echo "[+] Running kxss..."
cat all_urls.txt | gf xss | kxss > possible_xss.txt

# ----------------------------
# SecretFinder
# ----------------------------
echo "[+] Running SecretFinder..."
grep -Ei "\.js(\?|$)" all_urls.txt | sort -u | while read -r url; do
    python3 ~/Tools/SecretFinder.py -i "$url" -o cli >> possible_keys.txt
done

# ----------------------------
# JS Analysis
# ----------------------------
echo "[+] Starting JS file analysis..."
autofinder -f all_urls.txt

# ----------------------------
# Nuclei scanning
# ----------------------------
echo "[+] Running nuclei..."
cat live_domains.txt | awk '{print $1}' | nuclei -severity low,medium,high,critical -o nuclei_results.txt

# ----------------------------
# Deactivate virtualenv
# ----------------------------
if [ -n "${VIRTUAL_ENV:-}" ]; then
    deactivate
fi

echo "[+] Recon completed!"
echo "[+] All results saved in: $outdir"
                                        
