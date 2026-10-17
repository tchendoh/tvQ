import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment, assertSucceeds, assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, deleteDoc, serverTimestamp, Timestamp,
} from 'firebase/firestore';

let env;
const rules = readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8');

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'projet-tvq',
    firestore: { rules, host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/alice/followedShows/1399'), { followedAt: Timestamp.now() });
    await setDoc(doc(db, 'showsCache/1399_fr-CA'), { episodes: [], syncedAt: Timestamp.now() });
    await setDoc(doc(db, 'showMetadataCache/1399_fr-CA'), { show: { id: 1399 }, syncedAt: Timestamp.now() });
  });
});

const alice = () => env.authenticatedContext('alice').firestore();
const bob = () => env.authenticatedContext('bob').firestore();
const anon = () => env.unauthenticatedContext().firestore();

// Données personnelles
test('A lit, suit et ne suit plus ses séries', async () => {
  await assertSucceeds(getDoc(doc(alice(), 'users/alice/followedShows/1399')));
  await assertSucceeds(setDoc(doc(alice(), 'users/alice/followedShows/94605'), { followedAt: serverTimestamp() }));
  await assertSucceeds(deleteDoc(doc(alice(), 'users/alice/followedShows/1399')));
});
test('A supprime son document users (suppression de compte)', async () => {
  await assertSucceeds(deleteDoc(doc(alice(), 'users/alice')));
});
test('B ne peut ni lire ni écrire ni supprimer les données de A', async () => {
  await assertFails(getDoc(doc(bob(), 'users/alice/followedShows/1399')));
  await assertFails(setDoc(doc(bob(), 'users/alice/followedShows/1'), { followedAt: serverTimestamp() }));
  await assertFails(deleteDoc(doc(bob(), 'users/alice/followedShows/1399')));
  await assertFails(deleteDoc(doc(bob(), 'users/alice')));
});
test('Follow mal formé refusé', async () => {
  await assertFails(setDoc(doc(alice(), 'users/alice/followedShows/1'), { followedAt: Timestamp.fromDate(new Date(2000, 0, 1)) }));
  await assertFails(setDoc(doc(alice(), 'users/alice/followedShows/1'), { followedAt: serverTimestamp(), extra: 'x' }));
  await assertFails(setDoc(doc(alice(), 'users/alice/followedShows/abc'), { followedAt: serverTimestamp() }));
});

// Caches partagés
test('Utilisateur connecté lit et écrit un cache bien formé', async () => {
  await assertSucceeds(getDoc(doc(bob(), 'showsCache/1399_fr-CA')));
  await assertSucceeds(getDoc(doc(bob(), 'showMetadataCache/1399_fr-CA')));
  await assertSucceeds(setDoc(doc(bob(), 'showsCache/1399_original'), { episodes: [{ name: 'Winter Is Coming' }], syncedAt: Timestamp.now() }));
  await assertSucceeds(setDoc(doc(bob(), 'showMetadataCache/1399_en'), { show: { id: 1399 }, syncedAt: Timestamp.now() }));
});
test('Cache mal formé refusé', async () => {
  await assertFails(setDoc(doc(bob(), 'showsCache/pas-une-cle'), { episodes: [], syncedAt: Timestamp.now() }));
  await assertFails(setDoc(doc(bob(), 'showsCache/1_fr'), { episodes: [], syncedAt: Timestamp.now(), pirate: true }));
  await assertFails(setDoc(doc(bob(), 'showsCache/1_fr'), { episodes: 'texte', syncedAt: Timestamp.now() }));
  await assertFails(setDoc(doc(bob(), 'showsCache/1_fr'), { episodes: [], syncedAt: 'hier' }));
  await assertFails(setDoc(doc(bob(), 'showsCache/1_fr'), { episodes: [], syncedAt: Timestamp.fromDate(new Date(2099, 0, 1)) }));
  await assertFails(setDoc(doc(bob(), 'showMetadataCache/1_fr'), { show: 'x', syncedAt: Timestamp.now() }));
  await assertFails(setDoc(doc(bob(), 'showMetadataCache/1_fr'), { syncedAt: Timestamp.now() }));
});
test('Personne ne supprime un cache', async () => {
  await assertFails(deleteDoc(doc(bob(), 'showsCache/1399_fr-CA')));
  await assertFails(deleteDoc(doc(bob(), 'showMetadataCache/1399_fr-CA')));
});

// Visiteur non connecté et collections inconnues
test('Visiteur non connecté ne peut rien faire', async () => {
  await assertFails(getDoc(doc(anon(), 'users/alice/followedShows/1399')));
  await assertFails(getDoc(doc(anon(), 'showsCache/1399_fr-CA')));
  await assertFails(setDoc(doc(anon(), 'showsCache/1_fr'), { episodes: [], syncedAt: Timestamp.now() }));
});
test('Collection inconnue refusée', async () => {
  await assertFails(getDoc(doc(alice(), 'admin/config')));
  await assertFails(setDoc(doc(alice(), 'trending/1399'), { count: 999 }));
});
