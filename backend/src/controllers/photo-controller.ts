import { Request, Response } from "express";
// import { v4 as uuidv4 } from "uuid";
import { prisma } from "../db/prisma-client";
import {
  generateUploadURL,
  fileExists,
  deleteFile,
} from "../services/storage.service";

/**
 * POST /upload-url
 */
export const getUploadURL = async (req: Request, res: Response) => {
  const uid = req.auth?.uid;
const { v4: uuidv4 } = await import("uuid");
  const photoId = uuidv4();
  const path = `users/${uid}/photos/${photoId}.jpg`;

  const uploadURL = await generateUploadURL(path);

  res.json({ photoId, uploadURL });
};

export const finalizeUpload = async (req: Request, res: Response) => {
  const uid = req.auth?.uid;
  const { url } = req.body;
  const photoId = url.split("/").slice(-1)[0].split(".")[0];
  const path = `users/${uid}/photos/${photoId}.jpg`;
  const exists = await fileExists(path);
  if (!exists) {
    return res.status(422).json({ error: "File not uploaded" });
  }

  // 1. Get existing photos
  const profile = await prisma.profiles.findUnique({
    where: { user_id: uid },
    select: { photos: true },
  });

  let photos: any[] = [];

  if (profile?.photos) {
    photos = profile.photos as any[];
  }

  // 2. Add new photo
  photos.push({
    id: photoId,
    url: url,
    createdAt: new Date().toISOString(),
  });

  // 3. Save back to DB
  await prisma.profiles.update({
    where: { user_id: uid },
    data: {
      photos,
    },
  });

  res.json({ id: photoId, url });
};

export const deletePhoto = async (req: Request, res: Response) => {
  try {
    const uid = req.auth?.uid;
    const { photoId } = req.params;

    // 1. Get user's profile
    const profile = await prisma.profiles.findUnique({
      where: { user_id: uid },
      select: { photos: true },
    });

    if (!profile || !profile.photos) {
      return res.status(404).json({ error: "No photos found" });
    }

    let photos = profile.photos as any[];

    // 2. Find the photo
    const photoToDelete = photos.find((p) => p.id === photoId);

    if (!photoToDelete) {
      return res.status(404).json({ error: "Photo not found" });
    }

    // 3. Delete from storage (GCS)
    await deleteFile(photoToDelete.storagePath);

    // 4. Remove from array
    const updatedPhotos = photos.filter((p) => p.id !== photoId);

    // 5. Save back to DB
    await prisma.profiles.update({
      where: { user_id: uid },
      data: {
        photos: updatedPhotos,
      },
    });

    res.sendStatus(204);
  } catch (error) {
    console.error("Delete photo error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
}

export const reorderPhotos = async (req: Request, res: Response) => {
  try {
    const uid = req.auth?.uid;
    const { orderedPhotoIds } = req.body;

    // Validate input
    if (!Array.isArray(orderedPhotoIds)) {
      return res.status(400).json({ error: "Invalid input" });
    }

    // 1. Get user's profile
    const profile = await prisma.profiles.findUnique({
      where: { user_id: uid },
      select: { photos: true },
    });

    if (!profile || !profile.photos) {
      return res.status(404).json({ error: "No photos found" });
    }

    let photos = profile.photos as any[];

    // 2. Ensure all IDs belong to user
    const existingIds = photos.map((p) => p.id);

    const isValid = orderedPhotoIds.every((id: string) =>
      existingIds.includes(id)
    );

    if (!isValid) {
      return res.status(400).json({ error: "Invalid photo IDs" });
    }

    // 3. Reorder photos based on orderedPhotoIds
    const reorderedPhotos = orderedPhotoIds.map((id: string, index: number) => {
      const photo = photos.find((p) => p.id === id);

      return {
        ...photo,
        order: index, // update order
      };
    });

    // 4. Save back to DB
    await prisma.profiles.update({
      where: { user_id: uid },
      data: {
        photos: reorderedPhotos,
      },
    });

    res.status(200).json({ success: true });
  } catch (error) {
    console.error("Reorder photos error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
}