// Tendances de tvQ, calculées hors de l'app (Mac mini).
//
// Lit tous les documents users/{userID} :
//     { followedShows: { "1399": <Timestamp d'ajout>, ... }, ... }
// et écrit un seul document trends/current :
//     { updatedAt, userCount, mostFollowed: [{ showID, followers }],
//       risingThisWeek: [{ showID, added }] }
//
// Seulement des comptes agrégés : aucun identifiant d'utilisateur n'est écrit.
// Le SDK Admin ne passe pas par les règles de sécurité ni par App Check.
//
// Clé du compte de service : variable GOOGLE_APPLICATION_CREDENTIALS, sinon
// ~/.config/tvq/tvq-trends.json. Jamais dans le dépôt.
//
// Usage : node index.js [--dry-run]   (--dry-run : calcule et affiche, sans écrire)

import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const PROJECT_ID = "projet-tvq";
const TOP_COUNT = 20;
const RISING_WINDOW_DAYS = 7;
const DRY_RUN = process.argv.includes("--dry-run");

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  const defaultKey = join(homedir(), ".config", "tvq", "tvq-trends.json");
  if (!existsSync(defaultKey)) {
    console.error(`Clé introuvable : ${defaultKey} (ou définir GOOGLE_APPLICATION_CREDENTIALS).`);
    process.exit(1);
  }
  process.env.GOOGLE_APPLICATION_CREDENTIALS = defaultKey;
}

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

/// Les n entrées les plus élevées d'un compteur, à égalité triées par showID
/// pour un résultat stable d'une exécution à l'autre.
function top(counts, n, field) {
  return [...counts.entries()]
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, n)
    .map(([showID, count]) => ({ showID, [field]: count }));
}

async function main() {
  const since = Date.now() - RISING_WINDOW_DAYS * 24 * 60 * 60 * 1000;
  const followers = new Map();
  const added = new Map();

  const snapshot = await db.collection("users").get();
  for (const doc of snapshot.docs) {
    const followed = doc.get("followedShows");
    if (!followed || typeof followed !== "object") continue;
    for (const [showID, addedAt] of Object.entries(followed)) {
      followers.set(showID, (followers.get(showID) ?? 0) + 1);
      // Timestamp Firestore attendu ; une autre valeur compte comme suivie,
      // mais pas comme ajout récent.
      const millis = typeof addedAt?.toMillis === "function" ? addedAt.toMillis() : null;
      if (millis !== null && millis >= since) {
        added.set(showID, (added.get(showID) ?? 0) + 1);
      }
    }
  }

  const trends = {
    userCount: snapshot.size,
    mostFollowed: top(followers, TOP_COUNT, "followers"),
    risingThisWeek: top(added, TOP_COUNT, "added"),
  };

  console.log(
    `${new Date().toISOString()} : ${snapshot.size} utilisateurs, ` +
    `${followers.size} séries suivies, ${added.size} ajoutées en ${RISING_WINDOW_DAYS} jours.`
  );

  if (DRY_RUN) {
    console.log(JSON.stringify(trends, null, 2));
    console.log("--dry-run : rien n'a été écrit.");
    return;
  }

  await db.collection("trends").doc("current").set({
    ...trends,
    updatedAt: FieldValue.serverTimestamp(),
  });
  console.log("trends/current mis à jour.");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
