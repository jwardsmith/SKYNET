#!/bin/bash

# ANSI color codes
RED='\033[0;31m'
LIGHT_RED='\033[1;31m'
GREEN='\033[0;32m'
LIGHT_GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
LIGHT_BLUE='\033[1;34m'
MAGENTA='\033[0;35m'
LIGHT_MAGENTA='\033[1;35m'
CYAN='\033[0;36m'
LIGHT_CYAN='\033[1;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
ORANGE='\033[38;5;208m'
PINK='\033[38;5;205m'
BRIGHT_PURPLE='\033[38;5;141m'
BRIGHT_TEAL='\033[38;5;80m'
NEON_GREEN='\033[38;5;118m'
BRIGHT_YELLOW='\033[38;5;227m'
SKY_BLUE='\033[38;5;117m'
DEEP_PINK='\033[38;5;161m'
GOLD='\033[38;5;220m'
VIOLET='\033[38;5;99m'
RESET='\033[0m'

# Usage instructions
usage() {
    echo -e "${RED}Usage: $0 -f /path/to/auth.log${RESET}"
    exit 1
}

# Parse command-line options
while getopts "f:" opt; do
    case $opt in
        f) LOGFILE="$OPTARG" ;;
        *) usage ;;
    esac
done

# Validate input
if [ -z "$LOGFILE" ]; then
    usage
fi

if [ ! -f "$LOGFILE" ]; then
    echo -e "${RED}Log file not found: $LOGFILE${RESET}"
    exit 1
fi

echo -e "${BOLD}${CYAN}========================================${RESET}"
echo -e "${BOLD}${CYAN}Auth Log Analysis: $LOGFILE${RESET}"
echo -e "${BOLD}${CYAN}Generated on: $(date)${RESET}"
echo -e "${BOLD}${CYAN}========================================${RESET}"
echo

# 1. Failed login attempts (box width 34)
echo -e "${RED}${BOLD}==================================${RESET}"
echo -e "${RED}${BOLD}==== Failed password attempts ==== ${RESET}"
echo -e "${RED}${BOLD}==================================${RESET}"
echo

echo -e "${YELLOW}-- Summary (count → IP address) --${RESET}"
failed_ip_summary=$(grep "Failed password" "$LOGFILE" | awk '{print $(NF-3)}' | sort | uniq -c | sort -nr)
echo "$failed_ip_summary"
echo

echo -e "${YELLOW}-- Summary (count → usernames) --${RESET}"
failed_user_summary=$(grep "Failed password" "$LOGFILE" | awk '
{
  for(i=1;i<=NF;i++) {
    if ($i == "invalid" && $(i+1) == "user") {
      print $(i+2)
      break
    } else if ($i == "for" && $(i+1) != "invalid") {
      print $(i+1)
      break
    }
  }
}' | sort | uniq -c | sort -nr)
echo "$failed_user_summary"
echo

echo -e "${YELLOW}-- Full log entries by IP (sorted by frequency) --${RESET}"
echo "$failed_ip_summary" | awk '{print $2}' | while read ip; do
  echo -e "${BOLD}>> $ip${RESET}"
  grep "Failed password" "$LOGFILE" | grep "$ip" | sed 's/^/   /'
  echo
done

# 2. Successful login attempts (box width 34)
echo -e "${GREEN}${BOLD}===================================${RESET}"
echo -e "${GREEN}${BOLD}==== Successful login attempts ==== ${RESET}"
echo -e "${GREEN}${BOLD}===================================${RESET}"
echo

echo -e "${YELLOW}-- Summary (count → IP address) --${RESET}"
success_ip_summary=$(grep "Accepted password" "$LOGFILE" | awk '{print $(NF-3)}' | sort | uniq -c | sort -nr)
echo "$success_ip_summary"
echo

echo -e "${YELLOW}-- Summary (count → usernames) --${RESET}"
success_user_summary=$(grep "Accepted password" "$LOGFILE" | awk '
{
  for(i=1;i<=NF;i++) {
    if($i=="for") print $(i+1)
  }
}' | sort | uniq -c | sort -nr)
echo "$success_user_summary"
echo

echo -e "${YELLOW}-- Full log entries by IP (sorted by frequency) --${RESET}"
echo "$success_ip_summary" | awk '{print $2}' | while read ip; do
  echo -e "${BOLD}>> $ip${RESET}"
  grep "Accepted password" "$LOGFILE" | grep "$ip" | sed 's/^/   /'
  echo
done

# 3. Invalid user attempts (box width 34)
echo -e "${RED}${BOLD}=====================================${RESET}"
echo -e "${RED}${BOLD}==== Invalid user login attempts ==== ${RESET}"
echo -e "${RED}${BOLD}=====================================${RESET}"
echo

echo -e "${YELLOW}-- Summary (count → IP addresses) --${RESET}"
grep "Invalid user" "$LOGFILE" | sed -n 's/.*from \([^ ]*\) port.*/\1/p' | sort | uniq -c | sort -nr
echo

echo -e "${YELLOW}-- Summary (count → usernames) --${RESET}"
grep "Invalid user" "$LOGFILE" | sed -n 's/.*Invalid user \([^ ]*\) from .*/\1/p' | sort | uniq -c | sort -nr
echo

echo -e "${YELLOW}-- Full log entries by user (sorted by frequency) --${RESET}"
usernames=$(grep "Invalid user" "$LOGFILE" | sed -n 's/.*Invalid user \([^ ]*\) from .*/\1/p' | sort | uniq -c | sort -nr | awk '{print $2}')
for user in $usernames; do
    echo -e "${BOLD}>> $user${RESET}"
    grep "Invalid user $user" "$LOGFILE"
    echo
done

# 4. Top IPs involved in login attempts (box width 38)
echo -e "${BLUE}${BOLD}====================================${RESET}"
echo -e "${BLUE}${BOLD}==== Top IPs involved in logins ====  ${RESET}"
echo -e "${BLUE}${BOLD}====================================${RESET}"
echo

grep -E "Failed password|Accepted password" "$LOGFILE" | awk '{print $(NF-3)}' | sort | uniq -c | sort -nr | head -n 10
echo

# 5. Possible brute force indicators (box width 48)
echo -e "${MAGENTA}${BOLD}================================================${RESET}"
echo -e "${MAGENTA}${BOLD}==== Possible brute force IPs (failed > 10) ==== ${RESET}"
echo -e "${MAGENTA}${BOLD}================================================${RESET}"
echo

grep "Failed password" "$LOGFILE" | awk '{print $(NF-3)}' | sort | uniq -c | awk '$1 > 10' | sort -nr
echo

# 6. SSH root login attempts (box width 34)
echo -e "${CYAN}${BOLD}=================================${RESET}"
echo -e "${CYAN}${BOLD}==== SSH root login attempts ==== ${RESET}"
echo -e "${CYAN}${BOLD}=================================${RESET}"
echo

grep -E "(Failed|Accepted) password for root" "$LOGFILE"
echo

# 7. Sudo usage (box width 38)
echo -e "${ORANGE}${BOLD}====================================${RESET}"
echo -e "${ORANGE}${BOLD}==== Sudo usage (full commands) ====  ${RESET}"
echo -e "${ORANGE}${BOLD}====================================${RESET}"
echo

grep "COMMAND=" "$LOGFILE" | sed -n 's/.*COMMAND=//p' | sort | uniq -c | sort -nr
echo

# 8. New session creation events (box width 38)
echo -e "${GOLD}${BOLD}=====================================${RESET}"
echo -e "${GOLD}${BOLD}==== New session creation events ====  ${RESET}"
echo -e "${GOLD}${BOLD}=====================================${RESET}"
echo

echo -e "${YELLOW}-- Summary (count → user) --${RESET}"
new_session_summary=$(grep "New session" "$LOGFILE" | sed -n 's/.*New session [0-9]* of user \([^ ]*\)\..*/\1/p' | sort | uniq -c | sort -nr)
echo "$new_session_summary"
echo

echo -e "${YELLOW}-- Full log entries by user --${RESET}"
session_users=$(echo "$new_session_summary" | awk '{print $2}')
for user in $session_users; do
    echo -e "${BOLD}>> $user${RESET}"
    grep "New session" "$LOGFILE" | grep "user $user" | sed 's/^/   /'
    echo
done

# 9. Group additions (box width 26)
echo -e "${PINK}${BOLD}=========================${RESET}"
echo -e "${PINK}${BOLD}==== Group additions ==== ${RESET}"
echo -e "${PINK}${BOLD}=========================${RESET}"
echo

echo -e "${YELLOW}-- Summary (count → group name) --${RESET}"
grep "groupadd" "$LOGFILE" | sed -n 's/.*name=\([^,]*\).*/\1/p' | sort | uniq -c | sort -nr
echo

echo -e "${YELLOW}-- Full log entries --${RESET}"
grep "groupadd" "$LOGFILE" | sed 's/^/   /'
echo

# 10. User additions (box width 26)
echo -e "${NEON_GREEN}${BOLD}========================${RESET}"
echo -e "${NEON_GREEN}${BOLD}==== User additions ==== ${RESET}"
echo -e "${NEON_GREEN}${BOLD}========================${RESET}"
echo

echo -e "${YELLOW}-- Summary (count → user name) --${RESET}"
grep "useradd" "$LOGFILE" | sed -n 's/.*new user: name=\([^,]*\),.*/\1/p' | sort | uniq -c | sort -nr
echo

echo -e "${YELLOW}-- Full log entries --${RESET}"
grep "useradd" "$LOGFILE" | sed 's/^/   /'
echo

# 11. Password changes (box width 26)
echo -e "${VIOLET}${BOLD}==========================${RESET}"
echo -e "${VIOLET}${BOLD}==== Password changes ==== ${RESET}"
echo -e "${VIOLET}${BOLD}==========================${RESET}"
echo

echo -e "${YELLOW}-- Summary (count → user name) --${RESET}"
grep "password changed for" "$LOGFILE" | sed -n 's/.*password changed for \([^ ]*\)/\1/p' | sort | uniq -c | sort -nr
echo

echo -e "${YELLOW}-- Full log entries --${RESET}"
grep "password changed for" "$LOGFILE" | sed 's/^/   /'
echo

# 12. User detail changes (box width 28)
echo -e "${LIGHT_CYAN}${BOLD}=============================${RESET}"
echo -e "${LIGHT_CYAN}${BOLD}==== User detail changes ==== ${RESET}"
echo -e "${LIGHT_CYAN}${BOLD}=============================${RESET}"
echo

echo -e "${YELLOW}-- Summary (count → user name) --${RESET}"
grep "changed user" "$LOGFILE" | sed -n "s/.*changed user '\([^']*\)'.*/\1/p" | sort | uniq -c | sort -nr
echo

echo -e "${YELLOW}-- Full log entries --${RESET}"
grep "changed user" "$LOGFILE" | sed 's/^/   /'
echo

# 13. User modifications (group assignments) (box width 48)
echo -e "${RED}${BOLD}================================================${RESET}"
echo -e "${RED}${BOLD}==== User modifications (group assignments) ==== ${RESET}"
echo -e "${RED}${BOLD}================================================${RESET}"
echo

echo -e "${YELLOW}-- Summary (count → user name) --${RESET}"
grep "usermod" "$LOGFILE" | sed -n "s/.*add '\([^']*\)' to \(shadow \)\?group.*/\1/p" | sort | uniq -c | sort -nr
echo

echo -e "${YELLOW}-- Full log entries --${RESET}"
grep "usermod" "$LOGFILE" | sed 's/^/   /'
echo

echo -e "${CYAN}${BOLD}Analysis complete.${RESET}"
