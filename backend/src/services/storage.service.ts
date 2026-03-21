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
