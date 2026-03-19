import { Router } from "express";
import {
  getUploadURL,
  finalizeUpload,
  deletePhoto,
} from "../controllers/photo-controller";
import { verifyFirebaseToken } from "../middleware/auth";

export const photoRouter = Router();

photoRouter.post("/upload-url", verifyFirebaseToken, getUploadURL);
photoRouter.post("/finalize", verifyFirebaseToken, finalizeUpload);
photoRouter.delete("/:photoId", verifyFirebaseToken, deletePhoto);
