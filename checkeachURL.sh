
#Put the following into checklink.sh;   source ./checklink.sh  <filename>
## Where filename is a list of URLS you want checked
## Note: this should follow short Linkedin URLs to the dst
#
# https://hackertips.today

#!/usr/bin/env bash

INPUT="${1:?Usage: $0 <input-file>}"

GOOD="urls-200.txt"
ERRORS="urls-errors.txt"
UNRESOLVED="urls-unresolved.txt"

UA="Googlebot"
MAX_HOPS=10

# Initialize output files
: > "$GOOD"
: > "$ERRORS"
: > "$UNRESOLVED"

# Extract LinkedIn's external destination from HTML
extract_linkedin_url() {
    python3 -c '
import sys
from html.parser import HTMLParser
from urllib.parse import urljoin

class LinkedInParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.destination = None

    def handle_starttag(self, tag, attrs):
        if tag != "a" or self.destination:
            return

        attrs = dict(attrs)

        if attrs.get("data-tracking-control-name") == "external_url_click":
            href = attrs.get("href", "")

            if href.startswith(("http://", "https://")):
                self.destination = href

parser = LinkedInParser()
parser.feed(sys.stdin.read())

if parser.destination:
    print(parser.destination)
'
}

# Process one URL, following HTTP and LinkedIn redirects
check_url() {
    local url="$1"
    local status final result body next hop
    local -A visited=()

    for ((hop=1; hop<=MAX_HOPS; hop++)); do

        if [[ -n "${visited[$url]:-}" ]]; then
            echo "[LOOP] $url"
            printf '%s\n' "$url" >> "$UNRESOLVED"
            return
        fi

        visited[$url]=1

        body=$(mktemp)

        result=$(curl -sS -L \
            -A "$UA" \
            --connect-timeout 10 \
            --max-time 25 \
            --max-redirs 15 \
            --proto '=http,https' \
            --proto-redir '=http,https' \
            -o "$body" \
            -w '%{http_code} %{url_effective}' \
            "$url" 2>/dev/null)

        status="${result%% *}"
        final="${result#* }"

        if [[ ! "$status" =~ ^[0-9]{3}$ ]]; then
            echo "[FAILED] $url"
            printf '%s\n' "$url" >> "$UNRESOLVED"
            rm -f "$body"
            return
        fi

        # Only parse the LinkedIn intermediate page
        if [[ "$final" =~ ^https?://(www\.)?lnkd\.in/ ]] ||
           [[ "$final" =~ ^https?://([a-z0-9-]+\.)?linkedin\.com/ ]]; then

            next=$(extract_linkedin_url < "$body")

            if [[ -n "$next" ]]; then
                echo "  [LINKEDIN] $final"
                echo "  [FOLLOW]   $next"

                rm -f "$body"
                url="$next"
                continue
            fi
        fi

        rm -f "$body"

        case "$status" in
            200)
                if [[ "$final" =~ ^https?://(www\.)?lnkd\.in/ ]]; then
                    echo "[UNRESOLVED] $final"
                    printf '%s\n' "$final" >> "$UNRESOLVED"
                else
                    echo "[200] $final"
                    printf '%s\n' "$final" >> "$GOOD"
                fi
                ;;
            4??|5??)
                echo "[$status] $final"
                printf '%s %s\n' "$status" "$final" >> "$ERRORS"
                ;;
            *)
                echo "[OTHER $status] $final"
                printf '%s\n' "$final" >> "$UNRESOLVED"
                ;;
        esac

        return
    done

    echo "[MAX HOPS] $url"
    printf '%s\n' "$url" >> "$UNRESOLVED"
}

# Extract HTTP/HTTPS links and process sequentially
while IFS= read -r url; do
    echo
    echo "[CHECK] $url"
    check_url "$url"

done < <(
    grep -oP 'https?://[^\s"'"'"'<>]+' "$INPUT" | sort -u
)

# Remove duplicates
sort -u -o "$GOOD" "$GOOD"
sort -u -o "$ERRORS" "$ERRORS"
sort -u -o "$UNRESOLVED" "$UNRESOLVED"

echo
echo "========================================"
echo " URL CHECK COMPLETE"
echo "========================================"
echo " HTTP 200   : $(wc -l < "$GOOD")"
echo " 4xx / 5xx  : $(wc -l < "$ERRORS")"
echo " Unresolved : $(wc -l < "$UNRESOLVED")"
echo
echo " Results:"
echo "  $GOOD"
echo "  $ERRORS"
echo "  $UNRESOLVED"

