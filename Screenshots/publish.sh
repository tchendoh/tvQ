#!/bin/bash
# Publie les captures du README (ReadmeScreenshotsTests) sur le site tvq-site.
#
# 1. Lancer testReadmeScreenshots dans Xcode (Test Navigator).
# 2. Lancer ce script : ./Screenshots/publish.sh
#
# Il exporte les captures du dernier résultat de test dans Screenshots/raw/,
# les renomme d'après leur nom dans le test (home-en-light.png…), les réduit à
# 600 px de large dans tvq-site/screenshots/, puis propose de commiter et pousser.
#
# Dépôt du site : $TVQ_SITE, sinon ~/iOS/tvq-site.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
RAW="$REPO/Screenshots/raw"
SITE="${TVQ_SITE:-$HOME/iOS/tvq-site}"
DEST="$SITE/screenshots"
WIDTH=600

if [ ! -d "$SITE/.git" ]; then
    echo "Dépôt tvq-site introuvable : $SITE"
    echo "Indiquez son chemin avec TVQ_SITE=/chemin/vers/tvq-site $0"
    exit 1
fi

RESULT=$(ls -td ~/Library/Developer/Xcode/DerivedData/tvQ-*/Logs/Test/*.xcresult 2>/dev/null | head -1 || true)
if [ -z "$RESULT" ]; then
    echo "Aucun résultat de test trouvé. Lancez d'abord testReadmeScreenshots dans Xcode."
    exit 1
fi
echo "Résultat de test : $(basename "$RESULT") ($(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$RESULT"))"

rm -rf "$RAW"
xcrun xcresulttool export attachments --path "$RESULT" --output-path "$RAW" > /dev/null

# manifest.json : nom exporté (identifiant) -> nom donné dans le test, suivi de
# « _0_<identifiant> » qu'on retire.
mkdir -p "$DEST"
COUNT=0
while IFS=$'\t' read -r exported name; do
    sips --resampleWidth "$WIDTH" "$RAW/$exported" --out "$DEST/$name.png" > /dev/null
    echo "  $name.png"
    COUNT=$((COUNT + 1))
done < <(/usr/bin/python3 - "$RAW/manifest.json" <<'PY'
import json, re, sys
for test in json.load(open(sys.argv[1])):
    for a in test["attachments"]:
        name = re.sub(r"_\d+_[0-9A-F-]+\.png$", "", a["suggestedHumanReadableName"])
        print(f'{a["exportedFileName"]}\t{name}')
PY
)

if [ "$COUNT" -eq 0 ]; then
    echo "Aucune capture dans ce résultat de test (était-ce bien testReadmeScreenshots ?)."
    exit 1
fi
echo "$COUNT captures copiées dans $DEST"

cd "$SITE"
if git diff --quiet -- screenshots && [ -z "$(git ls-files --others --exclude-standard screenshots)" ]; then
    echo "Aucun changement dans tvq-site : rien à publier."
    exit 0
fi
git status --short screenshots
read -r -p "Commiter et pousser tvq-site ? [o/N] " answer
if [[ "$answer" =~ ^[oOyY]$ ]]; then
    git add screenshots
    git commit -q -m "Captures du README à jour"
    git push -q
    echo "Publié. GitHub Pages et le cache des images de GitHub peuvent prendre quelques minutes."
else
    echo "Rien n'a été commité. Les images sont dans $DEST."
fi
