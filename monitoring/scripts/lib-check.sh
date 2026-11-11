# Общие функции для скриптов проверки
FAILS=0; WARNS=0
ok()   { printf '  [ OK ] %s\n' "$1"; }
fail() { printf '  [FAIL] %s\n' "$1"; FAILS=$((FAILS+1)); }
warn() { printf '  [WARN] %s\n' "$1"; WARNS=$((WARNS+1)); }
check() { # check "описание" команда...
  local d="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$d"; else fail "$d"; fi
}
section() { printf '\n== %s ==\n' "$1"; }
summary() {
  printf '\nИтог: ошибок %d, предупреждений %d\n' "$FAILS" "$WARNS"
  [ "$FAILS" -eq 0 ] && echo "ГОТОВО" || echo "НЕ ГОТОВО"
  [ "$FAILS" -eq 0 ]
}
