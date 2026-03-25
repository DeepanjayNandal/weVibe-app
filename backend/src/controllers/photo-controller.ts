import { v4 as uuidv4 } from 'uuid';
import { Request, Response } from 'express';
import { Prisma } from '@prisma/client';
import { prisma } from '../db/prisma-client';
import { UserRepository } from '../repositories/user-repository';
import {
  generateUploadURL,
  generateReadURL,
  fileExists,
  deleteFile,
  AllowedMimeType,
} from '../services/storage.service';

interface StoredPhoto {
  id: string;
  storagePath: string;
  order: number;
  createdAt: string;
}

const MAX_PHOTOS = 6;
const ALLOWED_MIME_TYPES: AllowedMimeType[] = ['image/jpeg', 'image/png'];
const MAX_SIZE_BYTES = 10 * 1024 * 1024;
const userRepository = new UserRepository();

function toStoredPhotos(json: Prisma.JsonValue | null | undefined): StoredPhoto[] {
  if (!json || !Array.isArray(json)) return [];
  return json as unknown as StoredPhoto[];
}

function toJsonArray(photos: StoredPhoto[]): Prisma.InputJsonValue {
  return photos as unknown as Prisma.InputJsonValue;
}

async function resolveUserId(firebaseUid: string): Promise<string> {
  const user = await userRepository.findByFirebaseUid(firebaseUid);
  if (!user) throw new Error('USER_NOT_FOUND');
  return user.id;   // ← this is the actual UUID used in profiles.user_id
}

// POST /upload-url
export const getUploadURL = async (req: Request, res: Response) => {
  const firebaseUid = req.auth!.uid;
  const uid = await resolveUserId(firebaseUid);

  const { mimeType, sizeBytes } = req.body;

  if (!mimeType || !ALLOWED_MIME_TYPES.includes(mimeType)) {
    return res.status(400).json({ code: 'INVALID_MIME_TYPE', message: 'mimeType must be image/jpeg or image/png' });
  }

  if (typeof sizeBytes !== 'number' || sizeBytes < 1 || sizeBytes > MAX_SIZE_BYTES) {
    return res.status(400).json({ code: 'INVALID_SIZE', message: 'sizeBytes must be between 1 and 10485760' });
  }

  const profile = await prisma.profiles.findUnique({
    where: { user_id: uid },
    select: { photos: true },
  });
  const existingPhotos = toStoredPhotos(profile?.photos);
  if (existingPhotos.length >= MAX_PHOTOS) {
    return res.status(400).json({ code: 'MAX_PHOTOS_EXCEEDED', message: 'Maximum of 6 photos allowed' });
  }

  const photoId = uuidv4();
  const ext = mimeType === 'image/png' ? 'png' : 'jpg';
  const storagePath = `users/${uid}/photos/${photoId}.${ext}`;

  const uploadURL = await generateUploadURL(storagePath, mimeType);

  // Track the pending upload so the cleanup job can sweep unfinalized files
  // without scanning all profiles. Record is deleted in finalizeUpload.
  await prisma.photo_upload_pending.create({
    data: { photo_id: photoId, storage_path: storagePath, user_id: uid },
  });

  return res.json({ photoId, uploadURL });
};

// POST /finalize
export const finalizeUpload = async (req: Request, res: Response) => {
  const firebaseUid = req.auth!.uid;
  const uid = await resolveUserId(firebaseUid);

  const { photoId, order } = req.body;

  if (typeof photoId !== 'string' || photoId.trim().length === 0) {
    return res.status(400).json({ code: 'BAD_REQUEST', message: 'photoId is required' });
  }
  if (typeof order !== 'number' || !Number.isInteger(order) || order < 0) {
    return res.status(400).json({ code: 'BAD_REQUEST', message: 'order must be a non-negative integer' });
  }

  // Try .jpg first, then .png (matches ext chosen in getUploadURL)
  let storagePath = `users/${uid}/photos/${photoId}.jpg`;
  let exists = await fileExists(storagePath);
  if (!exists) {
    storagePath = `users/${uid}/photos/${photoId}.png`;
    exists = await fileExists(storagePath);
  }
  if (!exists) {
    return res.status(422).json({ code: 'PHOTO_NOT_UPLOADED', message: 'File not found in storage. Complete the GCS PUT before calling finalize.' });
  }

  // Re-check 6-photo cap at finalize time (race condition guard)
  const profile = await prisma.profiles.findUnique({
    where: { user_id: uid },
    select: { photos: true },
  });
  const existingPhotos = toStoredPhotos(profile?.photos);

  // Idempotency: if this photoId was already finalized (e.g. a retry after the iOS client
  // didn't receive our 200), just return the existing record rather than creating a duplicate.
  const alreadyFinalized = existingPhotos.find((p) => p.id === photoId);
  if (alreadyFinalized) {
    // Clean up the pending record in case finalize somehow ran twice before the
    // first transaction committed (extremely rare, safe to ignore not-found).
    await prisma.photo_upload_pending.deleteMany({ where: { photo_id: photoId } });
    const url = await generateReadURL(alreadyFinalized.storagePath);
    return res.json({ id: photoId, url });
  }

  if (existingPhotos.length >= MAX_PHOTOS) {
    return res.status(400).json({ code: 'MAX_PHOTOS_EXCEEDED', message: 'Maximum of 6 photos allowed' });
  }

  const newPhoto: StoredPhoto = {
    id: photoId,
    storagePath,
    order,
    createdAt: new Date().toISOString(),
  };

  // Atomically write the photo to the profile AND remove the pending-upload record.
  // If either operation fails the transaction rolls back: the profile stays unchanged
  // and the pending record remains, so iOS can retry and the cleanup job still fires.
  await prisma.$transaction([
    prisma.profiles.update({
      where: { user_id: uid },
      data: { photos: toJsonArray([...existingPhotos, newPhoto]) },
    }),
    prisma.photo_upload_pending.deleteMany({ where: { photo_id: photoId } }),
  ]);

  // Generate a fresh signed GET URL — never echo back the PUT URL
  const url = await generateReadURL(storagePath);

  return res.json({ id: photoId, url });
};

// DELETE /:photoId
export const deletePhoto = async (req: Request, res: Response) => {
  try {
    const firebaseUid = req.auth!.uid;
    const uid = await resolveUserId(firebaseUid);
    const { photoId } = req.params;

    const profile = await prisma.profiles.findUnique({
      where: { user_id: uid },
      select: { photos: true },
    });

    if (!profile || !profile.photos) {
      return res.status(404).json({ code: 'PHOTO_NOT_FOUND', message: 'No photos found' });
    }

    const photos = toStoredPhotos(profile.photos);
    const photoToDelete = photos.find((p) => p.id === photoId);

    if (!photoToDelete) {
      return res.status(404).json({ code: 'PHOTO_NOT_FOUND', message: 'Photo not found' });
    }

    // DB update first — if this succeeds the photo is removed from the user's profile
    // regardless of what happens to GCS. Reversing this order (GCS-first) risks a stale
    // DB reference pointing at a deleted file, which would surface as a broken image in iOS.
    const updatedPhotos = photos.filter((p) => p.id !== photoId);
    await prisma.profiles.update({
      where: { user_id: uid },
      data: { photos: toJsonArray(updatedPhotos) },
    });

    // GCS delete is best-effort. A failure leaves an orphaned file in storage but the
    // user's profile is already clean. Log it so ops can investigate if storage grows.
    try {
      await deleteFile(photoToDelete.storagePath);
    } catch (gcsErr) {
      console.error(`[photo-delete] GCS delete failed for ${photoToDelete.storagePath}:`, gcsErr);
    }

    return res.sendStatus(204);
  } catch (error) {
    console.error('Delete photo error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

// PATCH /reorder
export const reorderPhotos = async (req: Request, res: Response) => {
  try {
    const firebaseUid = req.auth!.uid;
    const uid = await resolveUserId(firebaseUid);
    const body = req.body;

    if (!Array.isArray(body) || body.length === 0) {
      return res.status(400).json({ code: 'BAD_REQUEST', message: 'Request body must be a non-empty JSON array' });
    }

    for (const entry of body) {
      if (
        typeof entry.photoId !== 'string' ||
        typeof entry.order !== 'number' ||
        !Number.isInteger(entry.order) ||
        entry.order < 0
      ) {
        return res.status(400).json({ code: 'BAD_REQUEST', message: 'Each entry must have photoId (string) and order (integer >= 0)' });
      }
    }

    const profile = await prisma.profiles.findUnique({
      where: { user_id: uid },
      select: { photos: true },
    });

    if (!profile || !profile.photos) {
      return res.status(404).json({ code: 'PHOTO_NOT_FOUND', message: 'No photos found' });
    }

    const photos = toStoredPhotos(profile.photos);
    const existingIds = new Set(photos.map((p) => p.id));

    for (const entry of body) {
      if (!existingIds.has(entry.photoId)) {
        return res.status(404).json({ code: 'PHOTO_NOT_FOUND', message: `Photo ${entry.photoId} not found` });
      }
    }

    const orderMap = new Map<string, number>(body.map((e: any) => [e.photoId, e.order]));
    const updatedPhotos = photos.map((photo) =>
      orderMap.has(photo.id) ? { ...photo, order: orderMap.get(photo.id)! } : photo
    );

    await prisma.profiles.update({
      where: { user_id: uid },
      data: { photos: toJsonArray(updatedPhotos) },
    });

    return res.status(200).json({});
  } catch (error) {
    console.error('Reorder photos error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};
