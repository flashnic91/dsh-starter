#!/bin/sh
# DSH Starter — установка части за вас.
#
# Что делает: ставит скиллы в ~/.agents/skills и показывает, чего не хватает.
# Чего не делает: не ставит плагины (это через интерфейс), не правит конфиги,
# ничего не удаляет.
#
# Запуск: sh install.sh            (покажет, что будет сделано)
#         sh install.sh --apply    (реально поставит скиллы)

set -eu

SKILLS_DIR="$HOME/.agents/skills"
SUPERPOWERS_URL="https://github.com/obra/superpowers.git"
APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

say() { printf '%s\n' "$*"; }
ok()  { printf '  [ок] %s\n' "$*"; }
no()  { printf '  [нет] %s\n' "$*"; }

say "DSH Starter"
say ""

# 1. Приложение на месте?
say "Проверка приложения"
if [ -d "$HOME/.dsh/profiles/desktop" ]; then
  ok "профиль найден: ~/.dsh/profiles/desktop"
else
  no "профиля нет — сначала установите DeepSeek Harness и запустите его один раз"
  say ""
  say "Дальше идти нет смысла. Ставьте приложение, запускайте, возвращайтесь."
  exit 1
fi

# 2. Терминальный CLI (не обязателен)
if command -v dsh >/dev/null 2>&1; then
  ok "команда dsh доступна"
  CLI=1
else
  no "команды dsh нет — плагины ставить через Настройки → Плагины → Маркетплейс"
  CLI=0
fi

# 3. Каталог скиллов
say ""
say "Проверка каталога скиллов"
if [ -d "$SKILLS_DIR" ]; then
  ok "$SKILLS_DIR (уже $(ls -1 "$SKILLS_DIR" | wc -l | tr -d ' ') папок)"
else
  if [ "$APPLY" = "1" ]; then
    mkdir -p "$SKILLS_DIR"
    ok "создан $SKILLS_DIR"
  else
    no "$SKILLS_DIR отсутствует — будет создан при --apply"
  fi
fi

# 4. Superpowers
say ""
say "Skills: Superpowers (15 штук)"
if [ -d "$SKILLS_DIR/using-superpowers" ]; then
  ok "уже стоят"
else
  if [ "$APPLY" = "1" ]; then
    TMP=$(mktemp -d)
    say "  качаю в $TMP ..."
    git clone --depth 1 "$SUPERPOWERS_URL" "$TMP/superpowers"
    # копируем только папки со SKILL.md, ничего не перезаписывая поверх чужого
    count=0
    for d in "$TMP"/superpowers/skills/*/; do
      name=$(basename "$d")
      if [ -f "$d/SKILL.md" ] && [ ! -e "$SKILLS_DIR/$name" ]; then
        cp -R "$d" "$SKILLS_DIR/$name"
        count=$((count + 1))
      fi
    done
    ok "поставлено папок: $count"
    say "  временная копия осталась в $TMP — удалить можно вручную"
  else
    no "не установлены — запустите с --apply"
  fi
fi

# 5. Плагины
say ""
say "Плагины"
if [ -f "$HOME/.dsh/profiles/desktop/package.json" ]; then
  have=$(grep -c '"' "$HOME/.dsh/profiles/desktop/package.json" || true)
  say "  список в ~/.dsh/profiles/desktop/package.json"
  if [ "$CLI" = "1" ]; then
    say "  ставить так: dsh plugin --profile desktop add <пакет>"
  else
    say "  ставить через Настройки → Плагины → Маркетплейс"
  fi
  say "  какие пакеты нужны и в каком порядке — docs/02-plugins.md"
else
  no "package.json профиля не найден"
fi

# 6. Правила
say ""
say "Правила для ассистента"
if [ -f "$HOME/.dsh/AGENTS.md" ]; then
  ok "уже есть ~/.dsh/AGENTS.md"
else
  no "нет ~/.dsh/AGENTS.md — взять шаблон config/AGENTS.md.template и положить туда"
fi

say ""
say "Готово. Дальше по README.md, шаг за шагом."
