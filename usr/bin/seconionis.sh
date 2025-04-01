#!/bin/bash

# Seconionis Tor Traffic Router
# Developer : root0emir 

# Seconionis version
VERSION="Seconionis 1.2"

TOR_EXCLUDE="192.168.0.0/16 172.16.0.0/12 10.0.0.0/8"

TOR_UID="debian-tor"

TOR_PORT="9040"

TOR_DNS="9053"

TORRC="/etc/tor/torrc"

GREEN=""
RED=""
REDB=""
YELLOW=""
BLUE=""
RESET=""

if [ -t 1 ]; then
    if tput setaf 0 &>/dev/null; then
        RESET="$(tput sgr0)"
        BOLD="$(tput bold)"
        GREEN="$(tput setaf 2)"
        RED="$(tput setaf 1)"
        REDB="${BOLD}${RED}"
        YELLOW="$(tput setaf 3)"
        BLUE="$(tput setaf 4)"
    else
        RESET="\e[0m"
        BOLD="\e[1m"
        GREEN="\e[32m"
        RED="\e[31m"
        REDB="${BOLD}${RED}"
        YELLOW="\e[33m"
        BLUE="\e[34m"
    fi
fi

BACKUPDIR="/var/lib/seconionis"

err() {
    echo "${RED}[-]${RESET} ERROR: ${@}"
    exit 1
}

warn() {
    echo "${YELLOW}[!]${RESET} WARNING: ${@}"
}

msg() {
    echo "${GREEN}[+]${RESET} ${@}"
}

info() {
    echo "${BLUE}[*]${RESET} ${@}"
}

banner() {
    echo -e "${REDB}[ Seconionis - Tor Traffic Router]${RESET}\n"
}

version() {
    echo "${VERSION}"
}

check_root() {
    if [ $(id -u) -ne 0 ]; then
        err "!-This script must be run as root"
    fi
}

check_backup_dir() {
    if [ ! -d $BACKUPDIR ]; then
        mkdir -p $BACKUPDIR
    fi
}

start_service() {
    SERVICE=${@}
    if [[ $(systemctl is-active $SERVICE) != "active" ]]; then
        warn "$SERVICE is not started"
        info "starting $SERVICE service"
        systemctl start $SERVICE || err "unable to start $SERVICE service"
        msg "started $SERVICE service"
    else
        warn "$SERVICE is running"
        info "reloading $SERVICE service"
        systemctl reload $SERVICE || err "unable to reload $SERVICE service"
        msg "reloaded $SERVICE service"
    fi

}

stop_service() {
    SERVICE=${@}
    if [[ $(systemctl is-active $SERVICE) == "active" ]]; then
        warn "$SERVICE is active"
        info "Stopping $SERVICE service"
        systemctl stop $SERVICE || err "Unable to stop $SERVICE service"
        msg "Stopped $SERVICE service"
    fi
}

is_started() {
    if [ -e $BACKUPDIR/started ]; then
        return 0
    fi
    return 1
}

flush_iptables() {
    iptables -F
    iptables -t nat -F
}

wipe() {
    echo 1024 >/proc/sys/vm/min_free_kbytes
    echo 3 >/proc/sys/vm/drop_caches
    echo 1 >/proc/sys/vm/oom_kill_allocating_task
    echo 1 >/proc/sys/vm/overcommit_memory
    echo 0 >/proc/sys/vm/oom_dump_tasks
    smem-secure-delete -fllv
}

get_ip() {
    TML=$(curl -s https://check.torproject.org/?lang=en_US)
	IP=$(echo "$HTML" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -n 1)
    echo "Public IP         : $IP"
}

backup_torrc() {
    warn "Backing up tor config..."
    mv "$TORRC" $BACKUPDIR/torrc.bak
    msg "[+]Backed up tor config"
}

backup_resolv_conf() {
    info "Backing up nameservers..."
    mv /etc/resolv.conf $BACKUPDIR/resolv.conf.bak
    msg "[+]Backed up nameservers"
}

backup_iptables() {
    info "Backing up iptables rules..."
    iptables-save >$BACKUPDIR/iptables.rules.bak
    msg "[+]Backed up iptables rules"
}

backup_sysctl() {
    info "Backing up sysctl rules..."
    sysctl -a >$BACKUPDIR/sysctl.conf.bak
    msg "[+]Backed up sysctl rules"
}

restore_torrc() {
    if [ -e $BACKUPDIR/torrc.bak ]; then
        warn "Restoring tor config..."
        rm -f /etc/tor/torrc
        mv $BACKUPDIR/torrc.bak /etc/tor/torrc
        msg "[+]Restored tor config"
    fi
}

restore_resolv_conf() {
    if [ -e $BACKUPDIR/resolv.conf.bak ]; then
        warn "Restoring nameservers..."
        rm -f $BACKUPDIR/resolv.conf
        mv $BACKUPDIR/resolv.conf.bak /etc/resolv.conf
        msg "[+]Restored nameservers"
    fi
}

restore_iptables() {
    if [ -e $BACKUPDIR/iptables.rules.bak ]; then
        warn "Restoring iptables rules"
        iptables-restore <$BACKUPDIR/iptables.rules.bak
        rm -f $BACKUPDIR/iptables.rules.bak
        msg "Restored iptables rules"
    fi
}

restore_sysctl() {
    if [ -e $BACKUPDIR/sysctl.conf.bak ]; then
        warn "[!]Restoring sysctl rules"
        sysctl -p $BACKUPDIR/sysctl.conf.bak &>"/dev/null"
        rm -f $BACKUPDIR/sysctl.conf.bak
        msg "[+]Restored sysctl rules"
    fi
}

gen_resolv_conf() {
    warn "Configuring nameservers..."
    cat >"/etc/resolv.conf" <<EOF
# generated by seconionis
nameserver 127.0.0.1
nameserver 1.1.1.1
nameserver 1.0.0.1
nameserver 208.67.222.222
nameserver 208.67.220.220
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
    chmod 644 /etc/resolv.conf
    msg "[+]Configured nameservers"
}

gen_torrc() {
    warn "Configuring tor"
    cat >"${TORRC}" <<EOF
# generated by seconionis
User $TOR_UID
DataDirectory /var/lib/tor
VirtualAddrNetwork 10.192.0.0/10
AutomapHostsOnResolve 1
AutomapHostsSuffixes .exit,.onion
TransPort 127.0.0.1:$TOR_PORT IsolateClientAddr IsolateSOCKSAuth IsolateClientProtocol IsolateDestPort IsolateDestAddr
SocksPort 127.0.0.1:9050 IsolateClientAddr IsolateSOCKSAuth IsolateClientProtocol IsolateDestPort IsolateDestAddr
ControlPort 9051
HashedControlPassword 16:FDE8ED505C45C8BA602385E2CA5B3250ED00AC0920FEC1230813A1F86F
DNSPort 127.0.0.1:$TOR_DNS
# Sandbox 1 - tor package is not built with --enable-seccomp required to use this option.
HardwareAccel 1
TestSocks 1
AllowNonRFC953Hostnames 0
WarnPlaintextPorts 23,109,110,143,80
ClientRejectInternalAddresses 1
NewCircuitPeriod 40
MaxCircuitDirtiness 600
MaxClientCircuitsPending 48
UseEntryGuards 1
EnforceDistinctSubnets 1
EOF
    chmod 644 ${TORRC}
    msg "[🗸]Configured tor"
}

apply_iptables_rules() {
    info "Applying iptables rules..."

    iptables -t nat -A OUTPUT -m owner --uid-owner $TOR_UID -j RETURN
    
    iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports $TOR_DNS
    iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports $TOR_DNS
    iptables -t nat -A OUTPUT -p udp -m owner --uid-owner $TOR_UID -m udp --dport 53 -j REDIRECT --to-ports $TOR_DNS

    iptables -t nat -A OUTPUT -p tcp -d 10.192.0.0/10 -j REDIRECT --to-ports $TOR_PORT
    iptables -t nat -A OUTPUT -p udp -d 10.192.0.0/10 -j REDIRECT --to-ports $TOR_PORT
    
    for NET in $TOR_EXCLUDE 127.0.0.0/9 127.128.0.0/10; do
        iptables -t nat -A OUTPUT -d $NET -j RETURN
        iptables -A OUTPUT -d "$NET" -j ACCEPT
    done

    iptables -t nat -A OUTPUT -p tcp --syn -j REDIRECT --to-ports $TOR_PORT
    iptables -t nat -A OUTPUT -p udp -j REDIRECT --to-ports $TOR_PORT
    iptables -t nat -A OUTPUT -p icmp -j REDIRECT --to-ports $TOR_PORT

    iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    iptables -A OUTPUT -m owner --uid-owner $TOR_UID -j ACCEPT
    iptables -A OUTPUT -j REJECT

    msg "[+]Applied iptables rules"
}

apply_sysctl_rules() {
    info "Applying sysctl rules..."

    # Disable Explicit Congestion Notification in TCP
    sysctl -w net.ipv4.tcp_ecn=0 &>"/dev/null"

    # window scaling
    sysctl -w net.ipv4.tcp_window_scaling=1 &>"/dev/null"

    # increase linux autotuning tcp buffer limits
    sysctl -w net.ipv4.tcp_rmem="8192 87380 16777216" &>"/dev/null"
    sysctl -w net.ipv4.tcp_wmem="8192 65536 16777216" &>"/dev/null"

    # increase TCP max buffer size
    sysctl -w net.core.rmem_max=16777216 &>"/dev/null"
    sysctl -w net.core.wmem_max=16777216 &>"/dev/null"

    # Increase number of incoming connections backlog
    sysctl -w net.core.netdev_max_backlog=16384 &>"/dev/null"
    sysctl -w net.core.dev_weight=64 &>"/dev/null"

    # Increase number of incoming connections
    sysctl -w net.core.somaxconn=32768 &>"/dev/null"

    # Increase the maximum amount of option memory buffers
    sysctl -w net.core.optmem_max=65535 &>"/dev/null"

    # Increase the tcp-time-wait buckets pool size to prevent simple DOS attacks
    sysctl -w net.ipv4.tcp_max_tw_buckets=1440000 &>"/dev/null"

    # try to reuse time-wait connections, but don't recycle them
    # (recycle can break clients behind NAT)
    sysctl -w net.ipv4.tcp_tw_reuse=1 &>"/dev/null"

    # Limit number of orphans, each orphan can eat up to 16M (max wmem)
    # of unswappable memory
    sysctl -w net.ipv4.tcp_max_orphans=16384 &>"/dev/null"
    sysctl -w net.ipv4.tcp_orphan_retries=0 &>"/dev/null"

    # don't cache ssthresh from previous connection
    sysctl -w net.ipv4.tcp_no_metrics_save=1 &>"/dev/null"
    sysctl -w net.ipv4.tcp_moderate_rcvbuf=1 &>"/dev/null"

    # Increase size of RPC datagram queue length
    sysctl -w net.unix.max_dgram_qlen=50 &>"/dev/null"

    # Don't allow the arp table to become bigger than this
    sysctl -w net.ipv4.neigh.default.gc_thresh3=2048 &>"/dev/null"

    # Tell the gc when to become aggressive with arp table cleaning.
    # Adjust this based on size of the LAN. 1024 is suitable for most
    # /24 networks
    sysctl -w net.ipv4.neigh.default.gc_thresh2=1024 &>"/dev/null"

    # Adjust where the gc will leave arp table alone - set to 32.
    sysctl -w net.ipv4.neigh.default.gc_thresh1=32 &>"/dev/null"

    # Adjust to arp table gc to clean-up more often
    sysctl -w net.ipv4.neigh.default.gc_interval=30 &>"/dev/null"

    # Increase TCP queue length
    sysctl -w net.ipv4.neigh.default.proxy_qlen=96 &>"/dev/null"
    sysctl -w net.ipv4.neigh.default.unres_qlen=6 &>"/dev/null"

    # Enable Explicit Congestion Notification (RFC 3168)you can disable if doesnt work
    sysctl -w net.ipv4.tcp_ecn=1 &>"/dev/null"
    sysctl -w net.ipv4.tcp_reordering=3 &>"/dev/null"

    # How many times to retry killing an alive TCP connection
    sysctl -w net.ipv4.tcp_retries2=15 &>"/dev/null"
    sysctl -w net.ipv4.tcp_retries1=3 &>"/dev/null"

    # Avoid falling back to slow start after a connection goes idle
    # keeps our cwnd large with the keep alive connections (kernel > 3.6)
    sysctl -w net.ipv4.tcp_slow_start_after_idle=0 &>"/dev/null"

    # Allow the TCP fastopen flag to be used,
    # beware some firewalls do not like TFO! (kernel > 3.7)
    sysctl -w net.ipv4.tcp_fastopen=3 &>"/dev/null"

    # This will enusre that immediatly subsequent connections use the new values
    sysctl -w net.ipv4.route.flush=1 &>"/dev/null"
    sysctl -w net.ipv6.route.flush=1 &>"/dev/null"

    # TCP SYN cookie protection
    sysctl -w net.ipv4.tcp_syncookies=1 &>"/dev/null"

    # TCP rfc1337
    sysctl -w net.ipv4.tcp_rfc1337=1 &>"/dev/null"

    # Reverse path filtering
    sysctl -w net.ipv4.conf.default.rp_filter=1 &>"/dev/null"
    sysctl -w net.ipv4.conf.all.rp_filter=1 &>"/dev/null"

    # Log martian packets
    sysctl -w net.ipv4.conf.default.log_martians=1 &>"/dev/null"
    sysctl -w net.ipv4.conf.all.log_martians=1 &>"/dev/null"

    # Disable ICMP redirecting
    sysctl -w net.ipv4.conf.all.accept_redirects=0 &>"/dev/null"
    sysctl -w net.ipv4.conf.default.accept_redirects=0 &>"/dev/null"
    sysctl -w net.ipv4.conf.all.secure_redirects=0 &>"/dev/null"
    sysctl -w net.ipv4.conf.default.secure_redirects=0 &>"/dev/null"
    sysctl -w net.ipv6.conf.all.accept_redirects=0 &>"/dev/null"
    sysctl -w net.ipv6.conf.default.accept_redirects=0 &>"/dev/null"
    sysctl -w net.ipv4.conf.all.send_redirects=0 &>"/dev/null"
    sysctl -w net.ipv4.conf.default.send_redirects=0 &>"/dev/null"

    # Enable Ignoring to ICMP Request
    sysctl -w net.ipv4.icmp_echo_ignore_all=1 &>"/dev/null"

    # Disable IPv6 for data leaks
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 &>"/dev/null"
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 &>"/dev/null"

    msg "[+]Applied sysctl rules"
}

start() {
    if is_started; then
        err "[!]Seconionis is already started"
    fi

    backup_torrc

    backup_resolv_conf

    backup_iptables

    backup_sysctl

    flush_iptables

    gen_torrc

    gen_resolv_conf

    start_service tor

    apply_iptables_rules

    apply_sysctl_rules

    msg "[✓]All traffic is successfully routed through the Tor network"

    touch $BACKUPDIR/started
}

stop() {
    if ! is_started; then
        err "[!]Seconionis is already stopped"
    fi

    restore_sysctl

    flush_iptables

    restore_iptables

    stop_service tor

    restore_torrc

    restore_resolv_conf

    rm -f $BACKUPDIR/started
}

changeid() {
    if ! is_started; then
        err "[!]Seconionis stopped"
    fi

    info "[>]Changing tor identity..."
    stop_service tor &>"/dev/null"
    sleep 1
    start_service tor &>"/dev/null"
    msg "[+]Tor identity changed"
}

changemac() {
    warn "[>]Changing mac addresses..."
    IFACES=$(ip -o link show | awk -F': ' '{print $2}')
    for IFACE in $IFACES; do
        if [ $IFACE != "lo" ]; then
            ip link set $IFACE down &>"/dev/null"
            macchanger -r $IFACE &>"/dev/null"
            ip link set $IFACE up &>"/dev/null"
        fi
    done
    msg "[+]Changed mac addresses"
}

revertvmac() {
    warn "[>]Reverting mac addresses..."
    IFACES=$(ip -o link show | awk -F': ' '{print $2}')
    for IFACE in $IFACES; do
        if [ $IFACE != "lo" ]; then
            ip link set $IFACE down &>"/dev/null"
            macchanger -p $IFACE &>"/dev/null"
            ip link set $IFACE up &>"/dev/null"
        fi
    done
    msg "Reverted mac addresses"
}

status() {
    TORSTATUS=$(systemctl is-active tor)

    AUTOWIPESTATUS=$(systemctl is-enabled seconionis-autowipe)

    AUTOSTARTSTATUS=$(systemctl is-enabled seconionis-autostart)

    if is_started; then
        msg "[+]Seconionis started"
    else
        warn "[!]Seconionis stopped"
    fi

    if [[ "${TORSTATUS}" == "active" ]]; then
        msg "[+]Tor service is: ${TORSTATUS}"
    else
        warn "[!]Tor service is: ${TORSTATUS}"
    fi

    if [[ "${AUTOWIPESTATUS}" == "enabled" ]]; then
        msg "[+]seconionis-autowipe service is: ${AUTOWIPESTATUS}"
    else
        warn "[!]seconionis-autowipe service is: ${AUTOWIPESTATUS}"
    fi

    if [[ "${AUTOSTARTSTATUS}" == "enabled" ]]; then
        msg "[+]seconionis-autostart service is: ${AUTOSTARTSTATUS}"
    else
        warn "[!]seconionis-autostart service is: ${AUTOSTARTSTATUS}"
    fi
}

autowipe() {
    warn "Enabling seconionis-autowipe..."
    systemctl enable seconionis-autowipe &>"/dev/null"
    msg "[+]Enabled Seconionis-autowipe"
}

autostart() {
    warn "Enabling seconionis-autostart..."
    systemctl enable seconionis-autostart &>"/dev/null"
    msg "[+]Enabled seconionis-autostart"
}

usage() {
    echo -e "Seconionis developed by root0emir \n"
    echo -e "A script to redirect all traffic through tor network\n"
    echo -e "Commands:"
    echo -e "  start      - Start tor and redirect all traffic through tor"
    echo -e "  stop       - Stop tor and redirect all traffic through tor"
    echo -e "  status     - Get info about Tor service status"
    echo -e "  restart    - Restart tor and traffic rules"
    echo -e "  autowipe   - Enable memory wipe at shutdown"
    echo -e "  autostart  - Start torctl at startup"
    echo -e "  ip         - Get remote ip address"
    echo -e "  changeid     - Change tor identity"
    echo -e "  changemac    - Change mac addresses of all interfaces"
    echo -e "  revertmac      - Revert mac addresses of all interfaces"
    echo -e "  version    - Print version of seconionis and exit\n"
}

main() {
    banner

    case "$1" in
    start)
        check_root
        check_backup_dir
        start
        ;;
    stop)
        check_root
        check_backup_dir
        stop
        ;;
    status)
        check_root
        check_backup_dir
        status
        ;;
    restart)
        check_root
        check_backup_dir
        stop
        sleep 1
        start
        ;;
    autowipe)
        check_root
        check_backup_dir
        autowipe
        ;;
    autostart)
        check_root
        check_backup_dir
        autostart
        ;;
    ip)
        get_ip
        ;;
    changeid)
        check_root
        check_backup_dir
        chngid
        ;;
    changemac)
        check_root
        check_backup_dir
        chngmac
        ;;
    revertmac)
        check_root
        check_backup_dir
        rvmac
        ;;
    version)
        version
        ;;
    wipe)
        check_root
        check_backup_dir
        wipe
        ;;
    *)
        usage
        exit 1
        ;;
    esac
    exit 0
}

main "${@}"

# EOF
