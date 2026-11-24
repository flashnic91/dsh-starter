#!/bin/sh
# DSH Starter — проверка и установка.
#
# Три режима:
#   sh install.sh           посмотреть, что будет сделано (ничего не меняет)
#   sh install.sh --check   аудит: полный список «что есть / чего нет»
#   sh install.sh --apply   поставить скиллы Superpowers
#
# Чего скрипт не делает: не ставит плагины (они через интерфейс), не правит
# настройки, ничего не удаляет.

set -eu

SKILLS_DIR="$HOME/.agents/skills"
PROFILE_DIR="$HOME/.dsh/profiles/desktop"
PATCH_FILE="$PROFILE_DIR/cordis.patch.yml"
SUPERPOWERS_URL="https://github.com/obra/superpowers.git"
HERE=$(cd "$(dirname "$0")" && pwd)

MODE=plan
case "${1:-}" in
  --apply) MODE=apply ;;
  --check) MODE=check ;;
  "") ;;
  *) echo "Неизвестный ключ: $1. Есть: --check, --apply."; exit 2 ;;
esac

READY=0
MISSING=0

say() { printf '%s\n' "$*"; }
ok()  { printf '  [ок] %s\n' "$*"; READY=$((READY + 1)); }
no()  { printf '  [нет] %s\n' "$*"; MISSING=$((MISSING + 1)); }
info() { printf '  %s\n' "$*"; }

say "DSH Starter — $([ "$MODE" = "check" ] && echo аудит || echo проверка)"
say ""

# --- 1. Приложение и профиль -------------------------------------------------
say "Приложение"
if [ -d "$PROFILE_DIR" ]; then
  ok "профиль $PROFILE_DIR"
else
  no "профиля нет. Сначала поставьте DeepSeek Harness, запустите, войдите в аккаунт"
  say ""
  say "Дальше идти нет смысла: без профиля ставить некуда."
  exit 1
fi

if command -v dsh >/dev/null 2>&1; then
  ok "команда dsh в терминале есть"
  CLI=1
else
  info "команды dsh нет — это нормально. Плагины ставятся из интерфейса:"
  info "Настройки → Плагины → Маркетплейс"
  MISSING=$((MISSING + 1))
  CLI=0
fi

# --- 2. Плагины из списка ----------------------------------------------------
say ""
say "Плагины (список: plugins.txt)"
if [ -f "$PROFILE_DIR/package.json" ]; then
  pkgs=$(grep -v '^[[:space:]]*#' "$HERE/plugins.txt" | grep '|' | awk -F'|' '{print $1}' | tr -d ' ')
  have=0
  lack=0
  for p in $pkgs; do
    case "$p" in
      dsh-whale-widget) continue ;;   # из маркета, версия не прибита
    esac
    if grep -q "\"$p\"" "$PROFILE_DIR/package.json" 2>/dev/null; then
      have=$((have + 1))
    else
      lack=$((lack + 1))
      missing_list="${missing_list:-}$p "
    fi
  done
  if [ "$lack" -eq 0 ]; then
    ok "все пакеты из списка стоят ($have)"
  else
    no "стоит $have, не хватает $lack: $missing_list"
    info "ставить по одному, имя из plugins.txt, порядок — docs/02-plugins.md"
  fi
else
  no "package.json профиля не найден"
fi

# --- 3. Каталог скиллов и Superpowers ---------------------------------------
say ""
say "Скиллы"
if [ -d "$SKILLS_DIR" ]; then
  n=$(ls -1 "$SKILLS_DIR" | wc -l | tr -d ' ')
  ok "каталог $SKILLS_DIR, папок: $n"
else
  if [ "$MODE" = "apply" ]; then
    mkdir -p "$SKILLS_DIR"
    ok "создан $SKILLS_DIR"
  else
    no "каталога $SKILLS_DIR нет — создаётся при --apply"
  fi
fi

if [ -d "$SKILLS_DIR/using-superpowers" ]; then
  ok "ядро Superpowers стоит"
else
  if [ "$MODE" = "apply" ]; then
    TMP=$(mktemp -d)
    info "качаю в $TMP ..."
    git clone --depth 1 "$SUPERPOWERS_URL" "$TMP/superpowers"
    count=0
    for d in "$TMP"/superpowers/skills/*/; do
      name=$(basename "$d")
      if [ -f "$d/SKILL.md" ] && [ ! -e "$SKILLS_DIR/$name" ]; then
        cp -R "$d" "$SKILLS_DIR/$name"
        count=$((count + 1))
      fi
    done
    ok "поставлено папок: $count"
    info "временная копия осталась в $TMP — можно удалить руками"
  else
    no "Superpowers не установлены — запустите sh install.sh --apply"
  fi
fi

# --- 4. Настройки ------------------------------------------------------------
say ""
say "Настройки ($PATCH_FILE)"
if [ -f "$PATCH_FILE" ]; then
  s=0
  for key in agent-default-model compaction-basic thresholdRatio retryPolicy permission; do
    if grep -q "$key" "$PATCH_FILE"; then s=$((s + 1)); fi
  done
  if [ "$s" -eq 5 ]; then
    ok "все пять ключевых блоков на месте"
  else
    no "найдено $s из 5 блоков: agent-default-model, compaction-basic, thresholdRatio, retryPolicy, permission"
    info "шаблоны — config/cordis.patch.example.yml и config/preset-cordis.yml"
  fi
  if [ -f "$PATCH_FILE.bak" ]; then
    ok "резервная копия $PATCH_FILE.bak есть"
  else
    info "копии .bak нет — сделайте до первой правки"
  fi
else
  no "$PATCH_FILE отсутствует"
fi

# --- 5. Правила ассистента ---------------------------------------------------
say ""
say "Правила ассистента"
if [ -f "$HOME/.dsh/AGENTS.md" ]; then
  ok "~/.dsh/AGENTS.md есть, строк: $(wc -l < "$HOME/.dsh/AGENTS.md" | tr -d ' ')"
else
  no "нет ~/.dsh/AGENTS.md — шаблон config/AGENTS.md.template"
fi

# --- 6. Память ---------------------------------------------------------------
say ""
say "Память"
found=""
for p in "$HOME"/Documents/*/memory/MEMORY.md "$HOME"/Documents/memory/MEMORY.md; do
  if [ -f "$p" ]; then found="$p"; break; fi
done
if [ -n "$found" ]; then
  ok "индекс памяти: $found"
else
  no "индекса памяти не видно — docs/05-memory.md, раздел «С чего начать»"
fi
if [ -f "$HOME/.dsh/AGENTS.md" ] && grep -qi "память\|memory" "$HOME/.dsh/AGENTS.md"; then
  ok "память упомянута в правилах — ассистент про неё знает"
else
  no "в ~/.dsh/AGENTS.md нет строки про память — ассистент не будет её читать"
fi

# --- Итог --------------------------------------------------------------------
say ""
say "Итого: готово $READY, не хватает $MISSING."
if [ "$MODE" = "check" ]; then
  say "Аудит ничего не менял. Дальше — по README.md, шаг за шагом."
elif [ "$MODE" = "apply" ]; then
  say "Скиллы поставлены. Плагины и настройки — шаги 2 и 4 в README.md."
else
  say "Это холостой прогон. Поставить скиллы: sh install.sh --apply"
fi
