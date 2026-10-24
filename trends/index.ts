// Tendances de tvQ, calculées hors de l'app (Mac mini).
//
// Lit tous les documents users/{userID} :
//     { followedShows: { "1399": <Timestamp d'ajout>, ... }, ... }
// et écrit un seul document trends/current :
//     { updatedAt, userCount, mostFollowed: [{ showID, url, followers }],
//       risingThisWeek: [{ showID, url, added }] }
// url : la fiche TMDB de la série, pratique pour consulter les données dans la console.
//
// Seulement des comptes agrégés : aucun identifiant d'utilisateur n'est écrit.
// Le SDK Admin ne passe pas par les règles de sécurité ni par App Check.
//
// Clé du compte de service : variable GOOGLE_APPLICATION_CREDENTIALS, sinon
// ~/.config/tvq/tvq-trends.json. Jamais dans le dépôt.
//
// Exécuté directement par Node (>= 22.18, suppression native des types) :
//     node index.ts [--dry-run]   (--dry-run : calcule et affiche, sans écrire)
// Vérification des types : npm run typecheck

import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import type { Timestamp } from "firebase-admin/firestore";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const PROJECT_ID = "projet-tvq";
const TOP_COUNT = 100;
const RISING_WINDOW_DAYS = 7;
const DRY_RUN = process.argv.includes("--dry-run");

/// Une entrée de classement : { showID, url, followers } ou { showID, url, added }.
type RankEntry<Field extends string> = { showID: string; url: string } & Record<Field, number>;

/// Fiche TMDB d'une série.
function tmdbURL(showID: string): string {
  return `https://www.themoviedb.org/tv/${showID}`;
}

/// Contenu de trends/current (sans updatedAt, ajouté à l'écriture).
interface Trends {
  userCount: number;
  mostFollowed: RankEntry<"followers">[];
  risingThisWeek: RankEntry<"added">[];
}

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
function top<Field extends string>(
  counts: Map<string, number>,
  n: number,
  field: Field,
): RankEntry<Field>[] {
  return [...counts.entries()]
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, n)
    .map(([showID, count]) => ({ showID, url: tmdbURL(showID), [field]: count }) as RankEntry<Field>);
}

/// Vrai si la valeur ressemble à un Timestamp Firestore.
function isTimestamp(value: unknown): value is Timestamp {
  return typeof (value as Timestamp | null)?.toMillis === "function";
}

function increment(counts: Map<string, number>, key: string): void {
  counts.set(key, (counts.get(key) ?? 0) + 1);
}

async function main(): Promise<void> {
  const since = Date.now() - RISING_WINDOW_DAYS * 24 * 60 * 60 * 1000;
  const followers = new Map<string, number>();
  const added = new Map<string, number>();

  const snapshot = await db.collection("users").get();
  for (const doc of snapshot.docs) {
    const followed: unknown = doc.get("followedShows");
    if (!followed || typeof followed !== "object") continue;
    for (const [showID, addedAt] of Object.entries(followed as Record<string, unknown>)) {
      increment(followers, showID);
      // Timestamp Firestore attendu ; une autre valeur compte comme suivie,
      // mais pas comme ajout récent.
      if (isTimestamp(addedAt) && addedAt.toMillis() >= since) {
        increment(added, showID);
      }
    }
  }

  const trends: Trends = {
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

main().catch((error: unknown) => {
  console.error(error);
  process.exit(1);
});
