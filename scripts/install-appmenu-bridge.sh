#!/bin/sh
set -eu

version="v1.0.36"
checksum="5b59b2084c5cb42f997d9b96a92c10bd2155e1a20e77b0f53a78f5c21c43152d"
asset="noctalia-appmenu-bridge-linux-x86_64"
url="https://github.com/yolo-labz/noctalia-appmenu/releases/download/${version}/${asset}"
bin_dir="${HOME}/.local/bin"
real_bin="${bin_dir}/noctalia-appmenu-bridge.bin"
launcher="${bin_dir}/noctalia-appmenu-bridge"
unit_dir="${HOME}/.config/systemd/user"
unit="${unit_dir}/quickshell-appmenu-bridge.service"
environment_dir="${HOME}/.config/environment.d"
environment_file="${environment_dir}/90-quickshell-appmenu.conf"

mkdir -p "$bin_dir" "$unit_dir" "$environment_dir"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT INT TERM

curl --fail --location --silent --show-error "$url" --output "$tmp"
printf '%s  %s\n' "$checksum" "$tmp" | sha256sum --check --status
install -m 0755 "$tmp" "$real_bin"

cat > "$launcher" <<'EOF'
#!/bin/sh
# The upstream release is built by Nix and records its Nix loader path.
# Fedora provides the same glibc loader at this stable location.
exec /lib64/ld-linux-x86-64.so.2 "$HOME/.local/bin/noctalia-appmenu-bridge.bin" "$@"
EOF
chmod 0755 "$launcher"

cat > "$environment_file" <<'EOF'
# Required for Qt applications to publish native menus over AT-SPI.
QT_ACCESSIBILITY=1
EOF

cat > "$unit" <<'EOF'
[Unit]
Description=Native application menu bridge for Quickshell
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=%h/.local/bin/noctalia-appmenu-bridge --foreground
Restart=on-failure
RestartSec=2
Environment=QT_ACCESSIBILITY=1

[Install]
WantedBy=graphical-session.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now quickshell-appmenu-bridge.service
"$launcher" --version-json
