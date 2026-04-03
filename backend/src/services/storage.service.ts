import { env } from '../config/env';
import { getStorageBucket } from '../config/firebase';

export type AllowedMimeType = 'image/jpeg' | 'image/png';

export const generateUploadURL = async (path: string, mimeType: AllowedMimeType): Promise<string> => {
  const file = getStorageBucket().file(path);

  const [url] = await file.getSignedUrl({
    version: 'v4',
    action: 'write',
    expires: Date.now() + 15 * 60 * 1000,
    contentType: mimeType,
  });

  return url;
};

export const generateReadURL = async (path: string): Promise<string> => {
  const file = getStorageBucket().file(path);

  const [url] = await file.getSignedUrl({
    version: 'v4',
    action: 'read',
    expires: Date.now() + 60 * 60 * 1000,
  });

  return url;
};

export const fileExists = async (path: string): Promise<boolean> => {
  const file = getStorageBucket().file(path);
  const [exists] = await file.exists();
  return exists;
};

export const deleteFile = async (path: string): Promise<void> => {
  const file = getStorageBucket().file(path);
  await file.delete();
};

export const deleteFilesByPrefix = async (prefix: string): Promise<{ attemptedCount: number; deletedCount: number; failedPaths: string[] }> => {
  if (env.authProviderMode === 'mock') {
    return { attemptedCount: 0, deletedCount: 0, failedPaths: [] };
  }

  const [files] = await getStorageBucket().getFiles({ prefix });

  if (files.length === 0) {
    return { attemptedCount: 0, deletedCount: 0, failedPaths: [] };
  }

  const results = await Promise.allSettled(files.map((file) => file.delete()));
  const failedPaths: string[] = [];
  let deletedCount = 0;

  results.forEach((result, index) => {
    if (result.status === 'fulfilled') {
      deletedCount += 1;
      return;
    }

    failedPaths.push(files[index].name);
  });

  return {
    attemptedCount: files.length,
    deletedCount,
    failedPaths,
  };
};
