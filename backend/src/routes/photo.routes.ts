import { Router } from "express";
import { authenticate } from '../middleware/authenticate';
import {
  getUploadURL,
  finalizeUpload,
  deletePhoto,
  reorderPhotos,
} from "../controllers/photo-controller";
import { createAuthVerifier } from "../services/auth/auth-verifier";

export const photoRouter = Router();
const authVerifier = createAuthVerifier();
photoRouter.post("/upload-url",   authenticate(authVerifier), getUploadURL);
photoRouter.post("/finalize", authenticate(authVerifier), finalizeUpload);
photoRouter.delete("/:photoId", authenticate(authVerifier), deletePhoto);
photoRouter.patch('/reorder', authenticate(authVerifier), reorderPhotos);
