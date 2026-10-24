// Tendances de tvQ, calculées hors de l'app (Mac mini).
//
// Source : tous les documents users/{userID} :
//     { followedShows: { "1399": <Timestamp d'ajout>, ... }, ... }
//
// À chaque exécution :
//   1. compte les abonnés de chaque série (la « photo » du jour) ;
//   2. enregistre cette photo dans trendsHistory/{AAAA-MM-JJ} (une par jour,
//      la dernière exécution de la journée remplace les précédentes) ;
//   3. compare avec la photo d'il y a N jours (--days, 7 par défaut) pour
//      obtenir la variation nette (ajouts moins retraits) ;
//   4. écrit trends/current :
//      { updatedAt, userCount, mostFollowed: [{ showID, url, followers }],
//        rising: [{ showID, url, gained }], risingDays, risingSince, risingMethod }
//
// Tant qu'il n'existe pas de photo assez ancienne, « rising » se replie sur les
// dates d'ajout encore présentes dans followedShows (risingMethod: "addedAt").
//
// Seulement des comptes agrégés : aucun identifiant d'utilisateur n'est écrit.
// Le SDK Admin ne passe pas par les règles de sécurité ni par App Check.
//
// Clé du compte de service : GOOGLE_APPLICATION_CREDENTIALS, sinon
// ~/.config/tvq/tvq-trends.json. Jamais dans le dépôt.
//
// Alerte en cas d'échec (facultatif) : si TVQ_ALERT_DIR est défini, un fichier
// JSON { type: "email", subject, text } y est déposé (format de claude-outbox).
//
// Usage : node index.ts [--dry-run] [--days N] [--top N]
// Vérification des types : npm run typecheck

import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import type { Timestamp } from "firebase-admin/firestore";
import { existsSync, writeFileSync } from "node:fs";
import { homedir, hostname } from "node:os";
import { join } from "node:path";
import { parseArgs } from "node:util";

const PROJECT_ID = "projet-tvq";
const TIME_ZONE = "America/Toronto";
const DAY_MS = 24 * 60 * 60 * 1000;

const { values: options } = parseArgs({
  options: {
    "dry-run": { type: "boolean", default: false },
    days: { type: "string", default: "7" },
    top: { type: "string", default: "100" },
  },
});
const DRY_RUN = options["dry-run"];
const RISING_DAYS = positiveInt(options.days, "--days");
const TOP_COUNT = positiveInt(options.top, "--top");

/// Une entrée de classement : { showID, url, followers } ou { showID, url, gained }.
type RankEntry<Field extends string> = { showID: string; url: string } & Record<Field, number>;

/// Photo d'un jour : nombre d'abonnés par série.
type Counts = Map<string, number>;

/// Document trendsHistory/{date}.
interface Snapshot {
  date: string;
  userCount: number;
  followers: Record<string, number>;
}

/// Contenu de trends/current (sans updatedAt, ajouté à l'écriture).
interface Trends {
  userCount: number;
  mostFollowed: RankEntry<"followers">[];
  rising: RankEntry<"gained">[];
  risingDays: number;
  risingSince: string | null;
  risingMethod: "snapshot" | "addedAt";
}

function positiveInt(raw: string, name: string): number {
  const value = Number(raw);
  if (!Number.isInteger(value) || value < 1) {
    console.error(`${name} attend un entier positif (reçu : ${raw}).`);
    process.exit(1);
  }
  return value;
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

/// Fiche TMDB d'une série.
function tmdbURL(showID: string): string {
  return `https://www.themoviedb.org/tv/${showID}`;
}

/// Date locale AAAA-MM-JJ (fuseau de Montréal), qui sert d'identifiant de photo.
function localDate(millis: number): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: TIME_ZONE }).format(millis);
}

/// Vrai si la valeur ressemble à un Timestamp Firestore.
function isTimestamp(value: unknown): value is Timestamp {
  return typeof (value as Timestamp | null)?.toMillis === "function";
}

function increment(counts: Counts, key: string, by = 1): void {
  counts.set(key, (counts.get(key) ?? 0) + by);
}

/// Les n entrées les plus élevées, à égalité triées par showID pour un
/// résultat stable d'une exécution à l'autre.
function top<Field extends string>(counts: Counts, n: number, field: Field): RankEntry<Field>[] {
  return [...counts.entries()]
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, n)
    .map(([showID, count]) => ({ showID, url: tmdbURL(showID), [field]: count }) as RankEntry<Field>);
}

/// La photo la plus récente datée au plus tard de `date`, ou null.
async function snapshotOnOrBefore(date: string): Promise<Snapshot | null> {
  const result = await db
    .collection("trendsHistory")
    .where("date", "<=", date)
    .orderBy("date", "desc")
    .limit(1)
    .get();
  return result.empty ? null : (result.docs[0].data() as Snapshot);
}

async function main(): Promise<void> {
  const now = Date.now();
  const today = localDate(now);
  const baselineDate = localDate(now - RISING_DAYS * DAY_MS);

  // 1. Photo du jour, et ajouts récents pour le repli.
  const followers: Counts = new Map();
  const addedRecently: Counts = new Map();
  const users = await db.collection("users").get();
  for (const doc of users.docs) {
    const followed: unknown = doc.get("followedShows");
    if (!followed || typeof followed !== "object") continue;
    for (const [showID, addedAt] of Object.entries(followed as Record<string, unknown>)) {
      increment(followers, showID);
      if (isTimestamp(addedAt) && addedAt.toMillis() >= now - RISING_DAYS * DAY_MS) {
        increment(addedRecently, showID);
      }
    }
  }

  // 2. Variation nette depuis la photo d'il y a N jours, si elle existe.
  const baseline = await snapshotOnOrBefore(baselineDate);
  let gained: Counts;
  if (baseline) {
    gained = new Map();
    const showIDs = new Set([...followers.keys(), ...Object.keys(baseline.followers)]);
    for (const showID of showIDs) {
      const delta = (followers.get(showID) ?? 0) - (baseline.followers[showID] ?? 0);
      if (delta > 0) gained.set(showID, delta);
    }
  } else {
    gained = addedRecently;
  }

  const trends: Trends = {
    userCount: users.size,
    mostFollowed: top(followers, TOP_COUNT, "followers"),
    rising: top(gained, TOP_COUNT, "gained"),
    risingDays: RISING_DAYS,
    risingSince: baseline?.date ?? null,
    risingMethod: baseline ? "snapshot" : "addedAt",
  };
  const snapshot: Snapshot = { date: today, userCount: users.size, followers: Object.fromEntries(followers) };

  console.log(
    `${new Date(now).toISOString()} : ${users.size} utilisateurs, ${followers.size} séries suivies, ` +
    `${gained.size} en hausse sur ${RISING_DAYS} jours ` +
    (baseline ? `(photo du ${baseline.date}).` : `(pas encore de photo du ${baselineDate} : repli sur les dates d'ajout).`)
  );

  if (DRY_RUN) {
    console.log(JSON.stringify(trends, null, 2));
    console.log(`--dry-run : rien n'a été écrit (photo ${today} non enregistrée).`);
    return;
  }

  const batch = db.batch();
  batch.set(db.collection("trendsHistory").doc(today), { ...snapshot, savedAt: FieldValue.serverTimestamp() });
  batch.set(db.collection("trends").doc("current"), { ...trends, updatedAt: FieldValue.serverTimestamp() });
  await batch.commit();
  console.log(`trends/current et trendsHistory/${today} mis à jour.`);
}

/// Dépose une alerte pour claude-outbox, si TVQ_ALERT_DIR est défini.
function sendAlert(error: unknown): void {
  const dir = process.env.TVQ_ALERT_DIR;
  if (!dir) return;
  const stamp = new Date().toISOString().replace(/[:.]/g, "-");
  const message = {
    type: "email",
    subject: "tvq-trends : échec du calcul des tendances",
    text:
      `L'exécution de tvq-trends a échoué sur ${hostname()} le ${new Date().toLocaleString("fr-CA", { timeZone: TIME_ZONE })}.\n\n` +
      `${error instanceof Error ? (error.stack ?? error.message) : String(error)}\n\n` +
      `Journaux : ~/Library/Logs/tvq-trends-error.log`,
  };
  try {
    writeFileSync(join(dir, `${stamp}_tvq-trends-echec.json`), JSON.stringify(message, null, 2));
  } catch (writeError) {
    console.error("Impossible de déposer l'alerte :", writeError);
  }
}

main().catch((error: unknown) => {
  console.error(error);
  sendAlert(error);
  process.exit(1);
});
