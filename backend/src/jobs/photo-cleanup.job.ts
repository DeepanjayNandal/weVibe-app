import { prisma } from '../db/prisma-client';
import { getStorageBucket } from '../config/firebase';

// ─── Cleanup logic ────────────────────────────────────────────────────────────

/**
 * Sweeps photo_upload_pending for records older than `orphanAgeMs` and deletes
 * the corresponding GCS files.
 *
 * Orphans arise when:
 *   1. iOS uploads bytes to GCS (step 2 of 3-step flow) but the finalize
 *      call (step 3) fails on all retries — the file exists in GCS with no
 *      DB record, and the pending row remains in photo_upload_pending.
 *   2. iOS never completes the GCS PUT at all — the pending row exists but
 *      there is no GCS file; the delete attempt returns 404 and is ignored.
 *
 * Safety guards:
 *   - Only touches paths recorded in photo_upload_pending — never touches
 *     arbitrary GCS paths.
 *   - The 1-hour age threshold lets in-flight uploads complete before
 *     considering a file orphaned.
 *   - 404 from GCS (file never uploaded) is silently ignored.
 *   - Other GCS errors are logged but don't abort the sweep.
 *   - The pending DB record is always deleted after attempting GCS removal,
 *     preventing repeated failed delete attempts for files that never existed.
 */
async function cleanupOrphanedPhotos(orphanAgeMs = 60 * 60 * 1000): Promise<void> {
  const cutoff = new Date(Date.now() - orphanAgeMs);

  // Only query the small pending table — no full profile scan needed.
  const pendingUploads = await prisma.photo_upload_pending.findMany({
    where: { created_at: { lt: cutoff } },
  });

  if (pendingUploads.length === 0) {
    console.log('[photo-cleanup] Sweep complete. No orphaned uploads found.');
    return;
  }

  const bucket = getStorageBucket();
  let deleted = 0;

  for (const pending of pendingUploads) {
    try {
      await bucket.file(pending.storage_path).delete();
      console.log(`[photo-cleanup] Deleted orphan: ${pending.storage_path}`);
      deleted++;
    } catch (err: any) {
      // GCS 404 means the file was never uploaded — that's fine, nothing to delete.
      if (err?.code !== 404) {
        console.error(`[photo-cleanup] Failed to delete ${pending.storage_path}:`, err);
      }
    }

    // Always remove the pending record whether the GCS delete succeeded, 404'd,
    // or failed — prevents the same path being retried every hour indefinitely.
    try {
      await prisma.photo_upload_pending.delete({ where: { id: pending.id } });
    } catch (dbErr) {
      console.error(`[photo-cleanup] Failed to remove pending record ${pending.id}:`, dbErr);
    }
  }

  console.log(
    `[photo-cleanup] Sweep complete. Processed ${pendingUploads.length} pending upload(s), deleted ${deleted} GCS file(s).`,
  );
}

// ─── Scheduler ────────────────────────────────────────────────────────────────

/**
 * Starts the photo cleanup job.
 * Runs immediately on server start (catches orphans from previous sessions),
 * then repeats on the given interval (default: every hour).
 */
export function startPhotoCleanupJob(intervalMs = 60 * 60 * 1000): void {
  const run = () =>
    cleanupOrphanedPhotos().catch((err) =>
      console.error('[photo-cleanup] Run failed:', err),
    );

  // Fire immediately, then schedule repeating runs.
  void run();
  setInterval(run, intervalMs);
}
